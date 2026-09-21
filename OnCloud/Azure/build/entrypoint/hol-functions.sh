#!/bin/bash
# *************************************************************************************************************#
# Setting required path and variables.

HOL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hol-output.sh
source "${HOL_LIB_DIR}/hol-output.sh"

# Jenkins mounts /userconfig with a different uid than the container process.
configure_git_for_userconfig() {
   git config --global --add safe.directory '*' 2>/dev/null || true
}

# Used only so azurerm validates admin_ssh_key during Keycloak terraform destroy (value is not applied to Azure).
HOL_KEYCLOAK_TF_DESTROY_SSH_PUBLIC_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIMlxNhPpySSn3QY//rLsJOLAuCnUR1OcLhuylTCVQ7q hol-keycloak-tf-destroy-placeholder'

hol_resolve_ssh_public_key_for_tf_destroy() {
   local ns="$1"
   local key_name="${2:-}"
   local key="${ssh_public_key:-}"
   local pem derived

   if [[ -n "$key" && "$key" != "placeholder" && "$key" =~ ^ssh-[a-z0-9-]+[[:space:]] ]]; then
      printf '%s\n' "$key"
      return 0
   fi

   for pem in \
      "/userconfig/.${ns}/${key_name}.pem" \
      "/userconfig/${key_name}.pem" \
      "/userconfig/.${ns}/keypair_gen/${workshop_name}-keypair.pem" \
      "/userconfig/.${ns}/${workshop_name}-keypair.pem"; do
      if [[ -n "$pem" && -f "$pem" ]]; then
         derived=$(ssh-keygen -y -f "$pem" 2>/dev/null) || continue
         printf '%s\n' "$derived"
         return 0
      fi
   done

   printf '%s\n' "$HOL_KEYCLOAK_TF_DESTROY_SSH_PUBLIC_KEY"
}

# Keycloak IP: persist per workshop at /userconfig/.${workshop_name}/keycloak_ip.
# Legacy /userconfig/keycloak_ip is read-only fallback during migration. Parallel Jenkins
# workshop jobs (e.g. PollSCM AWS+Azure on one agent) share the same host /userconfig mount.

hol_keycloak_ip_path() {
   local ns="${1:-${workshop_name:-}}"
   if [[ -z "$ns" ]]; then
      hol_fail "workshop_name is not set (cannot resolve Keycloak IP path)"
   fi
   echo "/userconfig/.${ns}/keycloak_ip"
}

hol_keycloak_ip_from_terraform() {
   local kc_tf_dir="/userconfig/.${workshop_name}/keycloak_terraform_config"
   local ip=""

   [[ -n "${workshop_name:-}" && -d "$kc_tf_dir" ]] || return 1
   ip=$(cd "$kc_tf_dir" && terraform output -raw elastic_ip 2>/dev/null || true)
   [[ -n "$ip" && "$ip" != "null" ]] || return 1
   printf '%s\n' "$ip"
}

hol_save_keycloak_ip() {
   local ip="$1"
   local path

   [[ -n "$ip" ]] || hol_fail "Cannot save empty Keycloak IP"
   [[ -n "${workshop_name:-}" ]] || hol_fail "workshop_name is not set (cannot save Keycloak IP)"
   path=$(hol_keycloak_ip_path)
   mkdir -p "/userconfig/.${workshop_name}"
   printf '%s\n' "$ip" >"$path"
}

# Order: per-workshop keycloak_ip file, legacy /userconfig/keycloak_ip, then Terraform elastic_ip.
# Partial destroy may leave a stale IP file if Keycloak destroy failed; cdp_idp_setup_user readiness
# check catches unreachable hosts. Successful destroy_keycloak removes the IP file and tf/ansible dirs.
resolve_keycloak_server_ip() {
   local mode="${1:-required}"
   local path legacy ip

   [[ -n "${workshop_name:-}" ]] || hol_fail "workshop_name is not set (cannot resolve Keycloak IP)"
   path=$(hol_keycloak_ip_path)

   if [[ -f "$path" ]]; then
      ip=$(tr -d '[:space:]' <"$path")
      if [[ -n "$ip" ]]; then
         printf '%s\n' "$ip"
         return 0
      fi
   fi

   legacy=/userconfig/keycloak_ip
   if [[ -f "$legacy" ]]; then
      ip=$(tr -d '[:space:]' <"$legacy")
      if [[ -n "$ip" ]]; then
         hol_warn "Using legacy Keycloak IP from ${legacy}; saving per-workshop copy at ${path}"
         hol_save_keycloak_ip "$ip"
         printf '%s\n' "$ip"
         return 0
      fi
   fi

   ip=$(hol_keycloak_ip_from_terraform 2>/dev/null || true)
   if [[ -n "$ip" ]]; then
      hol_warn "Keycloak IP file missing — recovered from Terraform output in /userconfig/.${workshop_name}/keycloak_terraform_config"
      hol_save_keycloak_ip "$ip"
      printf '%s\n' "$ip"
      return 0
   fi

   if [[ "$mode" == "optional" ]]; then
      return 1
   fi
   hol_fail "Keycloak server IP not found for workshop '${workshop_name}'. Checked: $(hol_keycloak_ip_path), legacy /userconfig/keycloak_ip, and terraform output elastic_ip under /userconfig/.${workshop_name}/keycloak_terraform_config. Parallel jobs on this Jenkins agent share /userconfig; use per-workshop storage and ensure Keycloak was not destroyed for this workshop."
}

hol_remove_keycloak_ip_on_destroy() {
   rm -f "$(hol_keycloak_ip_path)"
}

# True when per-workshop keycloak_ip or Keycloak Terraform elastic_ip output exists (provision rerun).
# Does not probe VM liveness; cdp_idp_setup_user waits for Keycloak HTTPS before Ansible.
hol_keycloak_already_provisioned() {
   resolve_keycloak_server_ip optional >/dev/null 2>&1
}

hol_keycloak_users_json_path() {
   local hol_session_name="$1"
   echo "/tmp/$(echo "$hol_session_name" | tr '[:upper:]' '[:lower:]').json"
}

# Validates keycloak_hol_user_fetch output for the workshop report. Always run fetch on rerun;
# hol_write_keycloak_workshop_report replaces any prior Keycloak block in the report file.
hol_load_keycloak_report_users() {
   local hol_session_name="$1"
   local json_path

   json_path=$(hol_keycloak_users_json_path "$hol_session_name")
   if [[ ! -f "$json_path" ]]; then
      hol_fail "Keycloak user export not found at ${json_path}. keycloak_hol_user_fetch did not write users (Keycloak unreachable, IDP setup failed, or fetch playbook did not run)."
   fi
   sample_keycloak_user1=$(jq -r '.[0].username // "n/a"' "$json_path")
   sample_keycloak_user2=$(jq -r '.[1].username // "n/a"' "$json_path")
}

# Remove an existing Keycloak block from the workshop report (rerun-safe).
hol_strip_keycloak_workshop_report_section() {
   local report_path="$1"
   local ws="$2"

   [[ -f "$report_path" ]] || return 0
   awk -v ws="$ws" '
   BEGIN { state=0 }
   state == 0 {
      if ($0 ~ /^={63}$/) { hold = $0 ORS; state = 1; next }
      printf "%s", $0 ORS
      next
   }
   state == 1 {
      if (index($0, "Keycloak Details For") && index($0, ws)) { state = 2; hold = ""; next }
      printf "%s%s", hold, $0 ORS
      hold = ""
      state = 0
      next
   }
   state == 2 {
      if ($0 ~ /^={63}$/) { state = 0 }
      next
   }
   ' "$report_path"
}

# Write Keycloak report section once per workshop report file (replace prior block).
hol_write_keycloak_workshop_report() {
   local report_path="/userconfig/${workshop_name}.txt"
   local tmp stripped

   tmp=$(mktemp)
   if [[ -f "$report_path" ]]; then
      stripped=$(hol_strip_keycloak_workshop_report_section "$report_path" "$workshop_name")
      printf '%s' "$stripped" | sed -e '${/^$/d;}' >"$tmp"
      if [[ -s "$tmp" ]]; then
         tail -c1 "$tmp" | read -r _ || echo >>"$tmp"
      fi
   else
      : >"$tmp"
   fi
   cat >>"$tmp" <<EOF
===============================================================
            Keycloak Details For ${workshop_name} HOL:           
===============================================================
Keycloak Server IP: ${KEYCLOAK_SERVER_IP}
Keycloak Admin HTTPS URL: https://${workshop_name}.${domain}
Keycloak Admin User: admin
Keycloak Admin Password: ${keycloak__admin_password}
Keycloak SSO HTTPS URL: https://${workshop_name}.${domain}/realms/master/protocol/saml/clients/cdp-sso
Numbers Of Users Created: ${number_of_workshop_users}
Sample Usernames: User1: ${sample_keycloak_user1}, User2: ${sample_keycloak_user2}
Default Password for HOL Users: ${workshop_user_default_password} 
UserAssignment App Admin URL: http://${KEYCLOAK_SERVER_IP}:5000/admin
UserAssignment App Participant URL: http://${KEYCLOAK_SERVER_IP}:5000/participant
===============================================================
EOF
   mv "$tmp" "$report_path"
}

#TF_QUICKSTART_VERSION=v0.8.0
USER_CONFIG_FILE="/userconfig/configfile"
KEYGEN_TF_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/keypair_gen
KC_TF_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/cdp-kc-config/keycloak_terraform_config
KC_ANS_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/cdp-kc-config/keycloak_ansible_config
DS_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/cdp-data-services
ENHANCEMENTS_TF_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/azure_enhancements/
CAII_SCRIPTS_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/CAII
USER_ACTION=$1

# ENABLE_DATA_SERVICES config (CSV, optional brackets). Must not use the name
# enable_data_services — hol_enable_data_services() is the provision entrypoint.
HOL_ENABLE_DATA_SERVICES=""

hol_trim() {
   local s="$1"
   s="${s#"${s%%[![:space:]]*}"}"
   s="${s%"${s##*[![:space:]]}"}"
   printf '%s' "$s"
}

hol_normalize_data_service_token() {
   local token
   token=$(hol_trim "$1" | tr '[:upper:]' '[:lower:]')
   case "$token" in
   cml) printf '%s' "cai" ;;
   none | "") printf '%s' "" ;;
   *) printf '%s' "$token" ;;
   esac
}

hol_enabled_data_services_csv() {
   local raw="${HOL_ENABLE_DATA_SERVICES:-}"
   raw="${raw//[/}"
   raw="${raw//]/}"
   raw=$(echo "$raw" | tr '[:upper:]' '[:lower:]')
   printf '%s' "$raw"
}

validating_variables() {
   hol_subsection "Validating configfile & input parameters" "📋"
   sleep 10
   if [ ! -f "/userconfig/configfile" ]; then
      hol_fail "Config file 'configfile' not found in /userconfig.
Please mount your config directory with -v and create a file named 'configfile' (no extension).
On Windows, use C:/Users/<Your_User>/ and try again." 9999
   fi
   # Cleaning up 'configfile' to remove ^M characters.
   sed -i 's/^M//g' $USER_CONFIG_FILE

   #--------------------------------------------------------------------------------------------------#

   # Function to check config file for missing keys and empty values
   check_config() {
      local USER_CONFIG_FILE="$1"

      # Define the required keys
      REQUIRED_KEYS=(
         "PROVISION_KEYCLOAK"
         # "AWS_ACCESS_KEY_ID"
         # "AWS_SECRET_ACCESS_KEY"
         "AZURE_REGION"
         #"SSH_KEY_NAME"
         "WORKSHOP_NAME"
         "NUMBER_OF_WORKSHOP_USERS"
         "WORKSHOP_USER_PREFIX"
         "WORKSHOP_USER_DEFAULT_PASSWORD"
         # "CDP_ACCESS_KEY_ID"
         # "CDP_PRIVATE_KEY"
         "CDP_DEPLOYMENT_TYPE"
         "LOCAL_MACHINE_IP"
         "ENABLE_DATA_SERVICES"
         "DOMAIN"
         "HOSTEDZONEID"
      )
      hol_kv "Provision Keycloak" "$provision_keycloak"
      # Conditionally add Keycloak keys based on PROVISION_KEYCLOAK
      if [[ "$provision_keycloak" == "yes" ]]; then
         REQUIRED_KEYS+=(
            # "KEYCLOAK_SERVER_NAME"
            "KEYCLOAK_ADMIN_PASSWORD"
            #"KEYCLOAK_SECURITY_GROUP_NAME"
         )
      fi

            # Conditionally validate LOCAL_MACHINE_IP for CAII
      if [[ "$provision_caii" == "yes" ]]; then
         if [[ "$local_ip" == "0.0.0.0/0" ]]; then
            hol_fail "LOCAL_MACHINE_IP cannot be '0.0.0.0/0' when PROVISION_CAII is 'yes'. Provide a restrictive IP or CIDR in configfile."
         fi
      fi


      # Check if user-provided config file exists
      if [ ! -f "$USER_CONFIG_FILE" ]; then
         hol_warn "User config file not found: $USER_CONFIG_FILE"
         return 1
      else
         hol_check_pass "Configfile present"
      fi

      # Function to check if a key exists in the config file
      key_exists() {
         grep -q "^$1:" "$USER_CONFIG_FILE"
      }

      # Function to check if a key has a non-empty value in the config file
      key_has_value() {
         local value=$(grep "^$1:" "$USER_CONFIG_FILE" | cut -d ':' -f2- | sed 's/ //g')
         [ -n "$value" ]
      }

      # Check for missing keys and empty values
      local MISSING_KEYS=()
      local EMPTY_VALUES=()
      for key in "${REQUIRED_KEYS[@]}"; do
         if ! key_exists "$key"; then
            MISSING_KEYS+=("$key")
         elif ! key_has_value "$key"; then
            EMPTY_VALUES+=("$key")
         fi
      done

      # Report missing keys
      if [ ${#MISSING_KEYS[@]} -gt 0 ]; then
         hol_warn "Missing keys in configfile:"
         for key in "${MISSING_KEYS[@]}"; do
            hol_kv "missing" "$key"
         done
      fi

      # Report keys with empty values
      if [ ${#EMPTY_VALUES[@]} -gt 0 ]; then
         hol_warn "Empty values in configfile:"
         for key in "${EMPTY_VALUES[@]}"; do
            hol_kv "empty" "$key"
         done
      fi

      # Exising on missing keys
      if [ ${#MISSING_KEYS[@]} -gt 0 ] || [ ${#EMPTY_VALUES[@]} -gt 0 ]; then
         hol_fail "Configfile validation failed. Update configfile and try again."
      fi

      #workshop_name variable to validate
      validate_workshop_name() {
         if [[ ! "$workshop_name" =~ ^[a-z0-9-]+$ || ${#workshop_name} -gt 12 ]]; then
            hol_fail "workshop_name must be 12 characters or less and use only lowercase letters, numbers, and hyphens."
         fi
      }
      validate_datalake_version() {
         if [[ -z "$datalake_version" || "$datalake_version" == "latest" || "$datalake_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            return 0 # Valid value
         else
            hol_fail "datalake_version must be 'latest' or a semantic version (e.g., 7.2.17)."
         fi
      }
      validate_workshop_name
      validate_datalake_version
   }

   #--------------------------------------------------------------------------------------------------#

   # Read variables from the text file
   while IFS=':' read -r key value; do
      if [[ $key && $value ]]; then
         key=$(echo "$key" | tr -d '[:space:]')     # Remove whitespace from the key
         value=$(echo "$value" | tr -d '[:space:]') # Remove whitespace from the value
         # Processing each variable
         case $key in
         PROVISION_KEYCLOAK)
            provision_keycloak=$(echo $value | tr '[:upper:]' '[:lower:]')
            ;;
         # KEYCLOAK_SERVER_NAME)
         #    ec2_instance_name=$(echo $value | tr '[:upper:]' '[:lower:]')
         #    ;;
         KEYCLOAK_ADMIN_PASSWORD)
            keycloak__admin_password=$value
            ;;
         #KEYCLOAK_SECURITY_GROUP_NAME)
         #   keycloak_sg_name=$(echo $value | tr '[:upper:]' '[:lower:]')
         #   ;;
         AWS_ACCESS_KEY_ID)
            aws_access_key_id=$value
            ;;
         AWS_SECRET_ACCESS_KEY)
            aws_secret_access_key=$value
            ;;
         AWS_SESSION_TOKEN)
            aws_session_token=$value
            ;;
         AWS_REGION)
            aws_region=$value
            ;;
         AZURE_REGION)
            azure_region=$(echo $value | tr '[:upper:]' '[:lower:]')
            ;;
         SSH_KEY_NAME|AWS_KEY_PAIR)
            ssh_key_name=$(echo $value | tr '[:upper:]' '[:lower:]')
            ;;
         AZURE_CLIENT_ID)
            azure_client_id=$value
            ;;
         AZURE_CLIENT_SECRET)
            azure_client_secret=$value
            ;;
         AZURE_TENANT_ID)
            azure_tenant_id=$value
            ;;
         AZURE_SUBSCRIPTION_ID)
            azure_subscription_id=$value
            ;;
         CDP_DEPLOYMENT_TYPE)
            if [[ "$value" == "public" || "$value" == "private" || "$value" == "semi-private" ]]; then
               deployment_template=$value
            else
               hol_fail "Invalid CDP_DEPLOYMENT_TYPE '${value}'. Allowed: public, private, semi-private." 9999
            fi
            ;;
         WORKSHOP_NAME)
            case $value in
            *_*)
               hol_fail "WORKSHOP_NAME cannot contain underscores. Update configfile and try again."
               ;;
            *)
               workshop_name=$(echo "$value" | tr '[:upper:]' '[:lower:'])
               ;;
            esac
            ;;
         NUMBER_OF_WORKSHOP_USERS)
            number_of_workshop_users=$value
            ;;
         WORKSHOP_USER_PREFIX)
            workshop_user_prefix=$(echo "$value" | tr '[:upper:]' '[:lower:'])
            ;;
         WORKSHOP_USER_DEFAULT_PASSWORD)
            workshop_user_default_password=$value
            ;;
         # New domain and hostedzoneid fields
         DOMAIN)
            if [[ -z "$value" || ! "$value" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
               hol_fail "Invalid DOMAIN value. Provide a valid domain name in configfile."
            else
               domain=$(echo $value | tr '[:upper:]' '[:lower:]')
            fi
            ;;
         HOSTEDZONEID)
            if [[ -z "$value" || ! "$value" =~ ^[A-Z0-9]{0,32}$ ]]; then
               hol_fail "Invalid HOSTEDZONEID. Use Route53 format: ZXXXXXXXXX"
            else
               hostedzoneid=$(echo $value | tr '[:lower:]' '[:upper:]')
            fi
            ;;
         # CDP_ACCESS_KEY_ID)
         #    cdp_access_key_id=$value
         #    ;;
         # CDP_PRIVATE_KEY)
         #    cdp_private_key=$value
         #    ;;
         LOCAL_MACHINE_IP)
            local_ip=$value
            ;;
         ENABLE_DATA_SERVICES)
            HOL_ENABLE_DATA_SERVICES=$value
            ;;
         CDW_VRTL_WAREHOUSE_SIZE)
            cdw_vrtl_warehouse_size=$(echo $value | tr '[:upper:]' '[:lower:]')
            ;;
         CDW_DATAVIZ_SIZE)
            cdw_dataviz_size=$(echo $value | tr '[:upper:]' '[:lower:]')
            ;;
         CDE_INSTANCE_TYPE)
            cde_instance_type="$value"
            ;;
         CDE_INITIAL_INSTANCES)
            cde_initial_instances=$value
            ;;
         CDE_MIN_INSTANCES)
            cde_min_instances=$value
            ;;
         CDE_MAX_INSTANCES)
            cde_max_instances=$value
            ;;
         CDE_SPARK_VERSION)
            cde_spark_version=$value
            ;;
         CDE_VC_TIER)
            cde_vc_tier=$value
            ;;
         CAI_WS_INSTANCE_TYPE)
            cai_ws_instance_type="$value"
            ;;
         CAI_MIN_INSTANCES)
            cai_min_instances=$value
            ;;
         CAI_MAX_INSTANCES)
            cai_max_instances=$value
            ;;
         CAI_ENABLE_GPU)
            cai_enable_gpu=$(echo $value | tr '[:upper:]' '[:lower:]')
            ;;
         CAI_GPU_INSTANCE_TYPE)
            cai_gpu_instance_type="$value"
            ;;
         CAI_MIN_GPU_INSTANCES)
            cai_min_gpu_instances=$value
            ;;
         CAI_MAX_GPU_INSTANCES)
            cai_max_gpu_instances=$value
            ;;
         CAI_NFS_VERSION)
            cai_nfs_version=$value
            ;;
         CDF_INSTANCE_TYPE)
            cdf_instance_type="$value"
            ;;
         CDF_MIN_NODES)
            cdf_min_nodes=$value
            ;;
         CDF_MAX_NODES)
            cdf_max_nodes=$value
            ;;
         CDF_USE_PUBLIC_LB)
            cdf_use_public_lb=$(echo $value | tr '[:upper:]' '[:lower:]')
            ;;
         CDP_SAML_PROVIDER_LIMIT)
            cdp_saml_provider_limit=$value
            ;;
         CDP_USER_LIMIT)
            cdp_user_limit=$value
            ;;
         CDP_GROUP_LIMIT)
            cdp_group_limit=$value
            ;;
         DATALAKE_VERSION)
            datalake_version=$value
            ;;
         PROVISION_CAII)
            provision_caii=$(echo $value | tr '[:upper:]' '[:lower:]')
            ;;
         # Can Add more cases if required.
         esac
      fi
   done <"$USER_CONFIG_FILE"

   while IFS= read -r line; do
      [[ -z "$line" || "$line" =~ ^# ]] && continue
      key="${line%%:*}"
      key=$(echo "$key" | tr -d '[:space:]\r')
      if [[ "$key" == "ENV_TAGS" ]]; then
         env_tags="${line#*:}"
         env_tags=$(echo "$env_tags" | tr -d '[:space:]\r')
         export env_tags
         break
      fi
   done < "$USER_CONFIG_FILE"

   export provision_caii="${provision_caii:-no}"
   export azure_client_id="${azure_client_id:-${AZURE_CLIENT_ID:-}}"
   export azure_client_secret="${azure_client_secret:-${AZURE_CLIENT_SECRET:-}}"
   export azure_tenant_id="${azure_tenant_id:-${AZURE_TENANT_ID:-}}"
   export azure_subscription_id="${azure_subscription_id:-${AZURE_SUBSCRIPTION_ID:-}}"
   export aws_access_key_id="${aws_access_key_id:-${AWS_ACCESS_KEY_ID:-}}"
   export aws_secret_access_key="${aws_secret_access_key:-${AWS_SECRET_ACCESS_KEY:-}}"
   export aws_session_token="${aws_session_token:-${AWS_SESSION_TOKEN:-}}"
   export aws_region="${aws_region:-${AWS_REGION:-us-east-1}}"

   # Call the function with the user-provided config file as an argument
   check_config "$USER_CONFIG_FILE"
   hol_ok "Configfile validated — input parameters verified"
}
#--------------------------------------------------------------------------------------------------------------#
# Function for checking .pem file.
key_pair_file() {
   USER_NAMESPACE=$workshop_name
   # Checking if SSH Keypair File exists.
   if [[ ! -f "/userconfig/$ssh_key_name.pem" ]]; then
      hol_fail "SSH key pair file not found: /userconfig/$ssh_key_name.pem" 9999
   else
      hol_step "Copying PEM file to user namespace"
      cp -pf "/userconfig/$ssh_key_name.pem" "/userconfig/.$USER_NAMESPACE/"
      export ssh_public_key=$(ssh-keygen -y -f "/userconfig/.$USER_NAMESPACE/$ssh_key_name.pem")
      hol_ok "SSH key pair copied"
   fi
}

check_key_pair() {
   USER_NAMESPACE=$workshop_name
   # Check if ssh_key_name exists as input
   # echo "USER_NAMESPACE: ${USER_NAMESPACE}"
   if [[ -z "$ssh_key_name" ]]; then
      # If keypair is empty, check if it's already generated and stored internally
      local generated_pem="/userconfig/.$USER_NAMESPACE/keypair_gen/${workshop_name}-keypair.pem"
      local copied_pem="/userconfig/.$USER_NAMESPACE/${workshop_name}-keypair.pem"
      if [[ -f "$generated_pem" || -f "$copied_pem" ]]; then
         export ssh_key_name=${workshop_name}-keypair
         local pem_path="$copied_pem"
         [[ -f "$generated_pem" ]] && pem_path="$generated_pem"
         export ssh_public_key=$(ssh-keygen -y -f "$pem_path")
         hol_ok "Using previously generated keypair: $ssh_key_name"
      else
         hol_info "No SSH key name provided — generating a new keypair"
         generate_keypair
      fi
   fi
}
#-------------------------------------------------------------------------------------------------#
# Function to setup AWS & CDP CLI for user.
#setup_aws_and_cdp_profile() {
#   echo "               =================================================================================="
#   echo "                                   Setting Up Your AWS & CDP Profile                               "
#   echo "               =================================================================================="
#   aws configure set aws_access_key_id $aws_access_key_id
#   aws configure set aws_secret_access_key $aws_secret_access_key
#   aws configure set default.region $aws_region
#   cdp configure set cdp_access_key_id $cdp_access_key_id
#   cdp configure set cdp_private_key $cdp_private_key
#}
#---------------------------------------------------------------------------------------------------------------------#
# Auth helpers — probe live CLI access only (no credential-file checks).
setup_azure_cli_auth() {
   if az account show --query id -o tsv &>/dev/null; then
      return 0
   fi
   if [[ -n "$azure_client_id" && -n "$azure_client_secret" && -n "$azure_tenant_id" ]]; then
      hol_step "Authenticating Azure CLI via service principal"
      if az login --service-principal -u "$azure_client_id" -p "$azure_client_secret" --tenant "$azure_tenant_id" --only-show-errors &>/dev/null; then
         [[ -n "$azure_subscription_id" ]] && az account set --subscription "$azure_subscription_id" --only-show-errors
         hol_ok "Azure CLI authenticated via service principal"
         return 0
      fi
   fi
   hol_fail "Azure CLI is not authenticated. Mount a host directory that contains 'az login' credentials to /root/.azure, or set AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, and AZURE_TENANT_ID in configfile or container environment variables."
}

setup_aws_cli_for_dns() {
   [[ "$provision_keycloak" != "yes" ]] && return 0
   if aws sts get-caller-identity --query Account --output text &>/dev/null; then
      return 0
   fi
   if [[ -n "${aws_access_key_id:-}" && -n "${aws_secret_access_key:-}" ]]; then
      hol_step "Configuring AWS CLI from configfile/environment for Route53 DNS"
      aws configure set aws_access_key_id "$aws_access_key_id" >/dev/null
      aws configure set aws_secret_access_key "$aws_secret_access_key" >/dev/null
      aws configure set default.region "${aws_region:-us-east-1}" >/dev/null
      if [[ -n "${aws_session_token:-}" ]]; then
         aws configure set aws_session_token "$aws_session_token" >/dev/null
      fi
   fi
}

ensure_aws_cli_for_dns() {
   [[ "$provision_keycloak" != "yes" ]] && return 0
   if ! command -v aws &>/dev/null; then
      hol_fail "AWS CLI is not installed in the container image."
   fi
   setup_aws_cli_for_dns
   if aws sts get-caller-identity --query Account --output text &>/dev/null; then
      return 0
   fi
   hol_fail "AWS CLI authentication required for Keycloak DNS (Route53). Mount host AWS credentials to /root/.aws, or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in configfile or container env. Verify on the host: aws sts get-caller-identity. On Apple Silicon Macs, run the container with --platform linux/amd64."
}

# Function to verify Azure pre-requisites
azure_prereq() {
   setup_azure_cli_auth
   hol_subsection "Checking Azure subscription quotas" "☁️"
   subscription_name=$(az account show --query name -o tsv 2>/dev/null)
   subscription_id=$(az account show --query id -o tsv 2>/dev/null)
   if [[ -z "$subscription_id" ]]; then
      hol_fail "Azure CLI is not authenticated after login attempt."
   fi
   hol_kv "Azure subscription" "${subscription_name:-$subscription_id}"

   vnet_count=$(az network vnet list --query "length(@)" -o tsv 2>/dev/null)
   hol_check_info "VNet count in subscription: ${vnet_count:-0}"

   if [[ "${vnet_count:-0}" -lt 950 ]]; then
      hol_check_pass "VNet quota available"
   else
      hol_quota_fail "VNet limit approaching in subscription. Remove unused VNets or request a quota increase."
   fi

   pip_count=$(az network public-ip list --query "length(@)" -o tsv 2>/dev/null)
   hol_check_info "Public IP count in subscription: ${pip_count:-0} (need 5 free)"

   if [[ "${pip_count:-0}" -lt 995 ]]; then
      hol_check_pass "Public IP quota available"
   else
      hol_quota_fail "Not enough free Public IPs in subscription. Release unused addresses or request a quota increase."
   fi

   # Check current storage account count
   storage_count=$(az storage account list --query "length(@)" -o tsv 2>/dev/null)
   hol_check_info "Storage account count: ${storage_count:-0}"

   if [[ "${storage_count:-0}" -lt 240 ]]; then
      hol_check_pass "Storage account quota available"
   else
      hol_quota_fail "Storage account limit approaching. Remove unused accounts or request a quota increase."
   fi
}
#---------------------------------------------------------------------------------------------------------------------#
# Function to validate if resources are already present on Azure.
check_azure_nsg_exists() {
   local nsg_name="$1"
   # Checking if Network Security Group exists.
   local nsg_count
   nsg_count=$(az network nsg list --query "[?name=='${nsg_name}'] | length(@)" -o tsv 2>/dev/null)
   # Validating the output
   if [[ "${nsg_count:-0}" -gt 0 ]]; then
      return 0
   else
      return 1
   fi
}
#---------------------------------------------------------------------------------------------------------------------#
# Function to verify CDP pre-requisites i.e. num_of_grps and num_of_saml_prvdrs
cdp_prereq() {
   hol_subsection "Checking CDP account limits" "📊"
   # echo "  cdp_group_limit: $cdp_group_limit"
   # Default Values
   DEFAULT_CDP_SAML_PROVIDER_LIMIT=10
   DEFAULT_CDP_USER_LIMIT=1000
   DEFAULT_CDP_GROUP_LIMIT=50

   #CDP_limit_variables
   export cdp_saml_provider_limit="${cdp_saml_provider_limit:-$DEFAULT_CDP_SAML_PROVIDER_LIMIT}"
   export cdp_user_limit="${cdp_user_limit:-$DEFAULT_CDP_USER_LIMIT}"
   export cdp_group_limit="${cdp_group_limit:-$DEFAULT_CDP_GROUP_LIMIT}"

   # Print Assigned Values for CDP_limits
   hol_kv "SAML provider limit" "$cdp_saml_provider_limit"
   hol_kv "User limit" "$cdp_user_limit"
   hol_kv "Group limit" "$cdp_group_limit"

   # Check current CDP IAM Groups count
   cdp_group_count=$(cdp iam list-groups | jq -r '.groups[].groupName' | wc -l)
   hol_check_info "CDP groups: ${cdp_group_count} (limit ${cdp_group_limit})"

   remaining_groups=$(($cdp_group_limit - $cdp_group_count))
   if [ "$remaining_groups" -lt 0 ]; then
      hol_quota_fail "Group count exceeds CDP_GROUP_LIMIT (${cdp_group_limit}). Increase CDP_GROUP_LIMIT in configfile."
   elif [ "$remaining_groups" -lt 2 ]; then
      hol_quota_fail "CDP IAM group limit reached. Increase quota or remove unused groups."
   else
      hol_check_pass "CDP IAM group quota available"
   fi

   # Check current CDP IAM Users count
   cdp_user_count=$(cdp iam list-users --max-items 10000 | jq -r '.users[].userId' | wc -l)
   hol_check_info "CDP users: ${cdp_user_count} (limit ${cdp_user_limit}, workshop users ${number_of_workshop_users})"

   remaining_users=$(($cdp_user_limit - $cdp_user_count))
   if [ "$remaining_users" -lt 0 ]; then
      hol_quota_fail "User count exceeds CDP_USER_LIMIT (${cdp_user_limit}). Increase CDP_USER_LIMIT in configfile."
   elif [ "$number_of_workshop_users" -gt "$remaining_users" ]; then
      hol_quota_fail "Not enough CDP user quota for ${number_of_workshop_users} workshop users."
   else
      hol_check_pass "CDP IAM user quota available"
   fi

   # Check current CDP SAML Providers count
   cdp_saml_provider_count=$(cdp iam list-saml-providers | jq -r '.samlProviders[].samlProviderName' | wc -l)
   hol_check_info "CDP SAML providers: ${cdp_saml_provider_count} (limit ${cdp_saml_provider_limit})"

   remaining_saml=$(($cdp_saml_provider_limit - $cdp_saml_provider_count))

   if [ "$remaining_saml" -lt 0 ]; then
      hol_quota_fail "SAML provider count exceeds CDP_SAML_PROVIDER_LIMIT (${cdp_saml_provider_limit})."
   elif [ "$remaining_saml" -eq 0 ]; then
      hol_quota_fail "CDP SAML provider limit reached. Increase quota or remove unused providers."
   else
      hol_check_pass "CDP SAML provider quota available"
   fi
}
#-------------------------------------------------------------------------------------------------#
# Function to provision Azure VM for Keycloak
generate_keypair() {
   hol_subsection "Generating keypair (if needed)" "🔑"
   USER_NAMESPACE=$workshop_name
   mkdir -p /userconfig/.$USER_NAMESPACE

   if [ ! -d "/userconfig/.$USER_NAMESPACE/$KEYGEN_TF_CONFIG_DIR" ]; then
      cp -R "$KEYGEN_TF_CONFIG_DIR" "/userconfig/.$USER_NAMESPACE/"
   fi

   cd /userconfig/.$USER_NAMESPACE/keypair_gen
   terraform init
   terraform apply -auto-approve \
      -var "keypair_name=$workshop_name"
   RETURN=$?
   if [ $RETURN -eq 0 ]; then
      export ssh_key_name=$(terraform output -raw ssh_key_name_output) #updated the value of ssh_key_name if initially not exists
      export ssh_public_key=$(terraform output -raw ssh_public_key_output)
      echo "true" >keypair_generated.flag                              # Store a flag to indicate the keypair was generated
      cp -f ${workshop_name}-keypair.pem /userconfig/.$USER_NAMESPACE/
      return 0
   else
      return 1
   fi
}

destroy_keypair() {
   hol_subsection "Destroying generated keypair" "🔑"
   USER_NAMESPACE=$workshop_name
   cd /userconfig/.$USER_NAMESPACE/keypair_gen
   terraform init
   terraform destroy -auto-approve \
      -var "keypair_name=$workshop_name"
   RETURN=$?
   if [ $RETURN -eq 0 ]; then
      rm -rf /userconfig/.$USER_NAMESPACE/keypair_gen
      return 0
   else
      return 1
   fi
}

save_keycloak_network_env() {
   local env_file="/userconfig/.$USER_NAMESPACE/keycloak_network.env"
   cat >"$env_file" <<EOF
KC_RESOURCE_GROUP=${KC_RESOURCE_GROUP}
KC_NETWORK_RG=${KC_NETWORK_RG}
KC_VNET_NAME=${KC_VNET_NAME}
KC_SUBNET_NAME=${KC_SUBNET_NAME}
EOF
}

load_keycloak_network_env() {
   local env_file="/userconfig/.$USER_NAMESPACE/keycloak_network.env"
   [[ -f "$env_file" ]] && source "$env_file"
}

resolve_keycloak_subnet_from_cdp_outputs() {
   local gateway_subnet private_subnet
   gateway_subnet=$(terraform output -json azure_cdp_gateway_subnet_names 2>/dev/null | jq -r '.[0] // empty')
   private_subnet=$(terraform output -json azure_cdp_subnet_names 2>/dev/null | jq -r '.[0] // empty')
   if [[ -n "$gateway_subnet" && "$gateway_subnet" != "null" ]]; then
      KC_SUBNET_NAME="$gateway_subnet"
      KC_SUBNET_SOURCE="gateway"
   elif [[ -n "$private_subnet" && "$private_subnet" != "null" ]]; then
      KC_SUBNET_NAME="$private_subnet"
      KC_SUBNET_SOURCE="cdp workload"
      hol_info "Gateway subnet output empty — using first CDP workload subnet for Keycloak"
   else
      KC_SUBNET_NAME=""
      KC_SUBNET_SOURCE=""
   fi
}

wait_for_keycloak_ready() {
   local host="${1:-}"
   local max_attempts="${2:-90}"
   local attempt=0 url code

   if [[ -z "$host" ]]; then
      host=$(resolve_keycloak_server_ip optional || true)
   fi
   [[ -z "$host" ]] && hol_fail "Keycloak host is not set for readiness check"

   url="https://${host}/realms/master/protocol/saml/descriptor"
   hol_step "Waiting for Keycloak HTTPS (${host}) — up to $((max_attempts * 10 / 60)) min..."

   while [[ $attempt -lt $max_attempts ]]; do
      code=$(curl -sk --connect-timeout 5 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")
      if [[ "$code" == "200" ]]; then
         hol_ok "Keycloak is ready"
         return 0
      fi
      attempt=$((attempt + 1))
      if [[ $((attempt % 6)) -eq 0 ]]; then
         hol_info "Keycloak not ready yet (HTTP ${code}) — waited $((attempt * 10))s"
      fi
      sleep 10
   done
   hol_fail "Keycloak did not become ready on ${host} within $((max_attempts * 10 / 60)) minutes"
}

get_cdp_network_for_keycloak() {
   local mode="${1:-required}"
   local azure_tf_dir="/userconfig/.$USER_NAMESPACE/cdp-tf-quickstarts/azure"

   if load_keycloak_network_env && [[ -n "$KC_RESOURCE_GROUP" && -n "$KC_SUBNET_NAME" ]]; then
      hol_kv "Keycloak resource group" "$KC_RESOURCE_GROUP"
      hol_kv "Keycloak network resource group" "$KC_NETWORK_RG"
      hol_kv "Keycloak VNet" "$KC_VNET_NAME"
      hol_kv "Keycloak subnet" "$KC_SUBNET_NAME"
      return 0
   fi

   if [[ ! -d "${azure_tf_dir}" ]]; then
      [[ "$mode" == "optional" ]] && return 1
      hol_fail "CDP Terraform directory not found at ${azure_tf_dir}. Provision CDP before Keycloak."
   fi
   cd "${azure_tf_dir}" || hol_fail "Unable to enter CDP Terraform directory: ${azure_tf_dir}"
   KC_RESOURCE_GROUP=$(terraform output -raw azure_resource_group_name 2>/dev/null || terraform output -raw azure_cdp_resource_group_name 2>/dev/null || true)
   KC_NETWORK_RG=$(terraform output -raw azure_network_resource_group_name 2>/dev/null || terraform output -raw azure_resource_group_name 2>/dev/null || terraform output -raw azure_cdp_resource_group_name 2>/dev/null || true)
   KC_VNET_NAME=$(terraform output -raw azure_vnet_name 2>/dev/null || true)
   resolve_keycloak_subnet_from_cdp_outputs
   if [[ -z "$KC_RESOURCE_GROUP" || -z "$KC_NETWORK_RG" || -z "$KC_VNET_NAME" || -z "$KC_SUBNET_NAME" ]]; then
      [[ "$mode" == "optional" ]] && return 1
      hol_warn "CDP network outputs: resource_group=${KC_RESOURCE_GROUP:-<empty>} network_rg=${KC_NETWORK_RG:-<empty>} vnet=${KC_VNET_NAME:-<empty>} subnet=${KC_SUBNET_NAME:-<empty>}"
      hol_fail "Unable to read CDP network outputs required for Keycloak. Ensure CDP Terraform apply completed and outputs azure_resource_group_name, azure_vnet_name, and azure_cdp_gateway_subnet_names (or azure_cdp_subnet_names) are set."
   fi
   save_keycloak_network_env
   hol_kv "Keycloak resource group" "$KC_RESOURCE_GROUP"
   hol_kv "Keycloak network resource group" "$KC_NETWORK_RG"
   hol_kv "Keycloak VNet" "$KC_VNET_NAME"
   hol_kv "Keycloak subnet (${KC_SUBNET_SOURCE:-unknown})" "$KC_SUBNET_NAME"
   return 0
}

# Recover CDP network variables from Keycloak Terraform state when CDP context is gone.
hol_recover_keycloak_network_from_terraform_state() {
   local kc_tf_dir="$1"
   local nic_subnet_id prev_dir="${PWD:-}"

   [[ -d "$kc_tf_dir" ]] || return 1
   cd "$kc_tf_dir" || return 1

   KC_RESOURCE_GROUP=$(terraform state show -no-color azurerm_linux_virtual_machine.keycloak 2>/dev/null \
      | awk -F' = ' '/resource_group_name/ { gsub(/"/, "", $2); print $2; exit }')
   nic_subnet_id=$(terraform state show -no-color azurerm_network_interface.keycloak 2>/dev/null \
      | awk -F' = ' '/subnet_id/ { gsub(/"/, "", $2); print $2; exit }')

   [[ -n "${prev_dir}" ]] && cd "$prev_dir" || true

   [[ -n "$KC_RESOURCE_GROUP" && -n "$nic_subnet_id" ]] || return 1
   KC_NETWORK_RG=$(sed -n 's|.*/resourceGroups/\([^/]*\)/providers.*|\1|p' <<<"$nic_subnet_id")
   KC_VNET_NAME=$(sed -n 's|.*/virtualNetworks/\([^/]*\)/subnets/.*|\1|p' <<<"$nic_subnet_id")
   KC_SUBNET_NAME=$(sed -n 's|.*/subnets/\([^/]*\)$|\1|p' <<<"$nic_subnet_id")
   [[ -n "$KC_NETWORK_RG" && -n "$KC_VNET_NAME" && -n "$KC_SUBNET_NAME" ]] || return 1
   return 0
}

setup_keycloak_vm() {
   hol_banner "Provisioning Keycloak" "🔐"
   USER_NAMESPACE=$workshop_name
   mkdir -p /userconfig/.$USER_NAMESPACE

   if [ ! -d "/userconfig/.$USER_NAMESPACE/$KC_TF_CONFIG_DIR" ]; then
      cp -R "$KC_TF_CONFIG_DIR" "/userconfig/.$USER_NAMESPACE/"
   fi

   if [ ! -d "/userconfig/.$USER_NAMESPACE/$KC_ANS_CONFIG_DIR" ]; then
      cp -R "$KC_ANS_CONFIG_DIR" "/userconfig/.$USER_NAMESPACE/"
   fi

   cd /userconfig/.$USER_NAMESPACE/keycloak_terraform_config

   ########## SSL Certs Genertaion Logic
   # DOMAIN=$domain               # Base domain (e.g., example.com)
   # HOSTED_ZONE_ID=$hostedzoneid # Route53 Hosted Zone ID
   # CERT_EMAIL=admin@$domain     # Email for Let's Encrypt (e.g., admin@example.com)
   # Check if required variables are provided
   if [[ -z "$workshop_name" || -z "$domain" || -z "$hostedzoneid" ]]; then
      hol_fail "Missing workshop_name, domain, or hostedzoneid for SSL certificate generation."
   fi
   # Derived Variables
   SUBDOMAIN="$workshop_name.$domain"
   hol_kv "Subdomain" "$SUBDOMAIN"
   hol_kv "Hosted Zone ID" "$hostedzoneid"
   CERT_PATH="/etc/letsencrypt/live/$domain"
   hol_subsection "Generating wildcard SSL certificates" "🔒"
   # Install Certbot if not installed
   if ! command -v certbot &>/dev/null; then
      hol_step "Installing certbot..."
      export DEBIAN_FRONTEND=noninteractive
      apt-get update >/dev/null 2>&1 && apt-get install -y certbot python3-certbot-dns-route53 >/dev/null 2>&1
   fi

   SSL_MOUNT_PATH=/userconfig/sslcerts/$domain
   mkdir -p $SSL_MOUNT_PATH
   # Check if certificates are already generated for the same domain name
   if [[ ! -f "$SSL_MOUNT_PATH/fullchain.pem" && ! -f "$SSL_MOUNT_PATH/privkey.pem" ]]; then
      hol_step "Generating SSL certificates for *.$domain..."
      # Generate Wildcard SSL Certificates
      certbot certonly \
         --dns-route53 \
         -d "*.$domain" \
         --non-interactive \
         --agree-tos \
         -m "admin@$domain"
      # Check if certificates were generated successfully
      if [[ ! -f "$CERT_PATH/fullchain.pem" || ! -f "$CERT_PATH/privkey.pem" ]]; then
         hol_fail "SSL certificate generation failed for *.$domain"
      fi
      hol_ok "SSL certificates generated for *.$domain"
      for file in /etc/letsencrypt/archive/$domain/*1.pem; do cp -v "$file" "$SSL_MOUNT_PATH/$(basename "$file" 1.pem).pem"; done
   else
      hol_skip "SSL certificates already exist for *.$domain"
   fi

   # Encode SSL Certificates in Base64 (for Terraform user_data)
   FULLCHAIN=$(cat "$SSL_MOUNT_PATH/fullchain.pem" | base64 -w 0)
   PRIVKEY=$(cat "$SSL_MOUNT_PATH/privkey.pem" | base64 -w 0)

   #######

   #local sg_name="$1"
   local sg_name="$workshop_name-keyc-sg"

   hol_subsection "Resolving CDP network for Keycloak" "🌐"
   get_cdp_network_for_keycloak

   hol_subsection "Running Terraform for Keycloak" "🏗️"
   if check_azure_nsg_exists "$sg_name"; then
      hol_warn "Security group '$sg_name' exists — using '$sg_name-$workshop_name-sg'"
      sg_name="$sg_name-$workshop_name"
   fi

   terraform init
   if terraform state list 2>/dev/null | grep -q 'azurerm_linux_virtual_machine.keycloak'; then
      hol_skip "Keycloak VM already exists in Terraform state — skipping apply"
      KEYCLOAK_SERVER_IP=$(terraform output -raw elastic_ip 2>/dev/null || true)
      if [[ -n "$KEYCLOAK_SERVER_IP" ]]; then
         hol_save_keycloak_ip "$KEYCLOAK_SERVER_IP"
         hol_kv "Keycloak instance IP" "$KEYCLOAK_SERVER_IP"
      fi
   else
   # Extract only the first IP for Keycloak (admin access only)
   kc_ip=$(echo "$local_ip" | cut -d',' -f1)

   if [[ -z "${ssh_public_key:-}" && -f "/userconfig/.${workshop_name}/${ssh_key_name}.pem" ]]; then
      export ssh_public_key=$(ssh-keygen -y -f "/userconfig/.${workshop_name}/${ssh_key_name}.pem")
   fi

   terraform apply -auto-approve \
      -var "workshop_name=$workshop_name" \
      -var "local_ip=$kc_ip" \
      -var "ssh_key_name=$ssh_key_name" \
      -var "ssh_public_key=$ssh_public_key" \
      -var "azure_region=$azure_region" \
      -var "domain=$domain" \
      -var "wildcard_fullchain=$FULLCHAIN" \
      -var "wildcard_privkey=$PRIVKEY" \
      -var "kc_security_group=$sg_name" \
      -var "keycloak_admin_password=$keycloak__admin_password" \
      -var "resource_group_name=$KC_RESOURCE_GROUP" \
      -var "network_resource_group_name=$KC_NETWORK_RG" \
      -var "vnet_name=$KC_VNET_NAME" \
      -var "subnet_name=$KC_SUBNET_NAME"

   RETURN=$?
   if [ $RETURN -ne 0 ]; then
      return 1
   fi
   KEYCLOAK_SERVER_IP=$(terraform output -raw elastic_ip)
   hol_step "Saving Keycloak IP to $(hol_keycloak_ip_path)"
   hol_save_keycloak_ip "$KEYCLOAK_SERVER_IP"
   hol_ok "Keycloak instance IP: $KEYCLOAK_SERVER_IP"
   fi

   # Fetch the public IP of the created Keycloak instance
   if [[ -z "$KEYCLOAK_SERVER_IP" ]]; then
      hol_fail "Unable to retrieve Keycloak instance IP after Terraform apply."
   fi

   hol_step "Updating Route53 DNS record for $SUBDOMAIN"
   # Update Route53 DNS record to map subdomain to instance IP
   aws route53 change-resource-record-sets --hosted-zone-id "$hostedzoneid" \
      --change-batch '{
        "Changes": [{
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "'"$SUBDOMAIN"'",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [{"Value": "'"$KEYCLOAK_SERVER_IP"'"}]
            }
        }]
    }'
   if [[ $? -ne 0 ]]; then
      hol_fail "Failed to update Route53 DNS record for $SUBDOMAIN"
   fi
   hol_ok "DNS record updated: $SUBDOMAIN -> $KEYCLOAK_SERVER_IP"
   hol_ok "Keycloak setup completed successfully"

}
#--------------------------------------------------------------------------------------------------#
# Function to rollback keycloack Azure VM in case of failure during provision.
destroy_keycloak() {
   USER_NAMESPACE=$workshop_name
   local kc_tf_dir="/userconfig/.$USER_NAMESPACE/keycloak_terraform_config"

   if [[ ! -d "$kc_tf_dir" ]]; then
      hol_skip "Keycloak Terraform directory not found — skipping Keycloak destroy"
      return 0
   fi

   hol_subsection "Destroying Keycloak" "🔐"
   local sg_name="${workshop_name}-keyc-sg"
   if check_azure_nsg_exists "$sg_name"; then
      sg_name="${sg_name}-${workshop_name}"
   fi

   cd "$kc_tf_dir"
   terraform init >/dev/null 2>&1
   if ! terraform state list 2>/dev/null | grep -q .; then
      hol_skip "Keycloak Terraform state is empty — skipping Keycloak destroy"
      hol_remove_keycloak_ip_on_destroy
      rm -rf "$kc_tf_dir" /userconfig/.$USER_NAMESPACE/keycloak_ansible_config
      return 0
   fi

   local kc_refresh_destroy=()
   load_keycloak_network_env || true
   if ! get_cdp_network_for_keycloak optional; then
      if [[ -z "${KC_RESOURCE_GROUP:-}" ]]; then
         if hol_recover_keycloak_network_from_terraform_state "$kc_tf_dir"; then
            hol_warn "CDP context missing — recovered Keycloak network targets from Terraform state"
         else
            hol_fail "Keycloak Terraform state exists under /userconfig/.${workshop_name}/ but network context is missing (no keycloak_network.env, CDP outputs, or recoverable VM/NIC state). Restore CDP terraform outputs or destroy Keycloak resources manually for workshop '${workshop_name}'."
         fi
      fi
      hol_warn "CDP network outputs unavailable — destroying Keycloak from saved or recovered network config (-refresh=false)"
      kc_refresh_destroy=(-refresh=false)
   fi

   hol_step "Waiting 30 seconds before Keycloak teardown..."
   sleep 30

   local keycloak_ip=""
   keycloak_ip=$(terraform output -raw elastic_ip 2>/dev/null || true)
   if [[ -n "$keycloak_ip" && -n "${hostedzoneid:-}" ]]; then
      hol_step "Deleting Route53 DNS record"
      if aws route53 change-resource-record-sets --hosted-zone-id "$hostedzoneid" \
         --change-batch '{
           "Changes": [{
               "Action": "DELETE",
               "ResourceRecordSet": {
                   "Name": "'"$workshop_name.$domain"'",
                   "Type": "A",
                   "TTL": 300,
                   "ResourceRecords": [{"Value": "'"$keycloak_ip"'"}]
               }
           }]
       }' 2>/dev/null; then
         hol_ok "DNS record deleted for $workshop_name.$domain"
      else
         hol_skip "Route53 A record not found or already removed ($workshop_name.$domain)"
      fi
   else
      hol_skip "No Keycloak IP or hosted zone — skipping Route53 cleanup"
   fi

   local kc_ip destroy_args kc_ssh_public_key
   kc_ip=$(echo "$local_ip" | cut -d',' -f1)
   kc_ssh_public_key=$(hol_resolve_ssh_public_key_for_tf_destroy "$USER_NAMESPACE" "${ssh_key_name:-}")
   destroy_args=(
      -auto-approve
      "${kc_refresh_destroy[@]}"
      -var "workshop_name=$workshop_name"
      -var "local_ip=$kc_ip"
      -var "ssh_key_name=${ssh_key_name:-placeholder}"
      -var "ssh_public_key=$kc_ssh_public_key"
      -var "azure_region=$azure_region"
      -var "domain=${domain:-example.com}"
      -var "wildcard_fullchain=placeholder"
      -var "wildcard_privkey=placeholder"
      -var "kc_security_group=$sg_name"
      -var "keycloak_admin_password=${keycloak__admin_password:-placeholder}"
   )
   if [[ -n "${KC_RESOURCE_GROUP:-}" ]]; then
      destroy_args+=(
         -var "resource_group_name=$KC_RESOURCE_GROUP"
         -var "network_resource_group_name=$KC_NETWORK_RG"
         -var "vnet_name=$KC_VNET_NAME"
         -var "subnet_name=$KC_SUBNET_NAME"
      )
   fi

   terraform destroy "${destroy_args[@]}"
   RETURN=$?
   if [ $RETURN -eq 0 ]; then
      hol_remove_keycloak_ip_on_destroy
      rm -rf "$kc_tf_dir" /userconfig/.$USER_NAMESPACE/keycloak_ansible_config /userconfig/.$USER_NAMESPACE/keycloak_network.env
      return 0
   else
      return 1
   fi
}
#--------------------------------------------------------------------------------------------------#
# Sync cdp-tf-quickstarts without deleting terraform state or workshop files.
sync_cdp_tf_quickstarts() {
   local quickstart_dir="$1"
   local cloud_path="$2"
   local repo_url="https://github.com/cloudera-labs/cdp-tf-quickstarts.git"
   local git_err=""
   local -a git_safe=(git -c safe.directory='*' -c "safe.directory=${quickstart_dir}")

   configure_git_for_userconfig

   if [[ -d "${quickstart_dir}/.git" ]]; then
      hol_step "Updating cdp-tf-quickstarts (${TF_QUICKSTART_VERSION})"
      cd "${quickstart_dir}" || hol_fail "Unable to enter cdp-tf-quickstarts directory."
      "${git_safe[@]}" fetch --depth 1 origin "${TF_QUICKSTART_VERSION}" 2>/dev/null \
         || "${git_safe[@]}" fetch --depth 1 origin "refs/tags/${TF_QUICKSTART_VERSION}:refs/tags/${TF_QUICKSTART_VERSION}" 2>/dev/null \
         || "${git_safe[@]}" fetch --depth 1 origin
      if ! git_err=$("${git_safe[@]}" checkout -f "${TF_QUICKSTART_VERSION}" 2>&1); then
         hol_fail "Unable to checkout ${TF_QUICKSTART_VERSION} in cdp-tf-quickstarts: ${git_err}"
      fi
      "${git_safe[@]}" sparse-checkout init --cone
      "${git_safe[@]}" sparse-checkout set "${cloud_path}"
      "${git_safe[@]}" checkout @ &>/dev/null
      hol_ok "cdp-tf-quickstarts updated"
      return 0
   fi

   if [[ -e "${quickstart_dir}" ]]; then
      hol_warn "Quickstart path exists but is not a git repo — recloning"
      rm -rf "${quickstart_dir}"
   fi

   hol_step "Cloning cdp-tf-quickstarts (${TF_QUICKSTART_VERSION})"
   if ! "${git_safe[@]}" clone "${repo_url}" -b "${TF_QUICKSTART_VERSION}" --single-branch --depth 1 "${quickstart_dir}"; then
      hol_fail "Failed to clone cdp-tf-quickstarts (branch/tag: ${TF_QUICKSTART_VERSION})."
   fi
   cd "${quickstart_dir}" || hol_fail "Unable to enter cdp-tf-quickstarts directory."
   "${git_safe[@]}" sparse-checkout init --cone
   "${git_safe[@]}" sparse-checkout set "${cloud_path}"
   "${git_safe[@]}" checkout @ &>/dev/null
}

# Azure NSG rules reject 0.0.0.0/0 combined with more-specific CIDRs.
normalize_ingress_cidrs() {
   local input="$1"
   local -a cidrs=()
   local cidr normalized=""

   IFS=',' read -ra raw <<< "$input"
   for cidr in "${raw[@]}"; do
      cidr=$(echo "$cidr" | xargs)
      [[ -z "$cidr" ]] && continue
      cidrs+=("$cidr")
   done

   for cidr in "${cidrs[@]}"; do
      if [[ "$cidr" == "0.0.0.0/0" ]]; then
         if [[ "${#cidrs[@]}" -gt 1 ]]; then
            hol_warn "LOCAL_MACHINE_IP contains 0.0.0.0/0 with other CIDRs — using 0.0.0.0/0 only (Azure NSG overlap restriction)"
         fi
         echo "0.0.0.0/0"
         return 0
      fi
   done

   normalized=$(printf '%s\n' "${cidrs[@]}" | awk '!seen[$0]++' | paste -sd, -)
   echo "$normalized"
}

build_cdp_ingress_cidr_tf_list() {
   local normalized
   normalized=$(normalize_ingress_cidrs "$local_ip")
   normalized=$(echo "$normalized" | sed 's/,/\",\"/g')
   echo "\"${normalized}\""
}

should_provision_cdw() {
   local csv
   csv=$(hol_enabled_data_services_csv)
   [[ ",${csv}," == *",cdw,"* ]]
}

should_provision_cde() {
   local csv
   csv=$(hol_enabled_data_services_csv)
   [[ ",${csv}," == *",cde,"* ]]
}

should_apply_ai_registry_storage_access() {
   [[ "${provision_caii:-no}" == "yes" ]] && return 0
   local csv
   csv=$(hol_enabled_data_services_csv)
   [[ ",${csv}," == *",cai,"* ]]
}

resolve_datalake_storage_account() {
   if [[ -n "${DATA_STORAGE_ACCOUNT:-}" ]]; then
      return 0
   fi
   local azure_tf_dir="/userconfig/.${workshop_name}/cdp-tf-quickstarts/azure"
   if [[ -d "$azure_tf_dir" ]]; then
      DATA_STORAGE_ACCOUNT=$(cd "$azure_tf_dir" && terraform output -raw azure_data_storage_account 2>/dev/null || true)
      export DATA_STORAGE_ACCOUNT
   fi
   [[ -n "${DATA_STORAGE_ACCOUNT:-}" ]]
}

# Return 0 when CAI or CAII is selected and Azure NFS should be provisioned.
should_provision_cai_nfs() {
   [[ "${provision_caii:-no}" == "yes" ]] && return 0
   local csv
   csv=$(hol_enabled_data_services_csv)
   [[ ",${csv}," == *",cai,"* ]]
}

cdp_nfs_enabled_in_state() {
   terraform state list 2>/dev/null | grep -q "module.cdp_azure_prereqs.module.azure_cml_nfs"
}

# Wire create_azure_cml_nfs into cdp-tf-quickstarts (not exposed in root module by default).
patch_cdp_quickstart_for_cai_nfs() {
   local azure_tf_dir="$1"
   local main_tf="${azure_tf_dir}/main.tf"
   local variables_tf="${azure_tf_dir}/variables.tf"
   local outputs_tf="${azure_tf_dir}/outputs.tf"

   if ! grep -q "create_azure_cml_nfs" "$variables_tf"; then
      cat <<'EOF' >>"$variables_tf"

variable "create_azure_cml_nfs" {
  type        = bool
  description = "Whether to create NFS for CAI/CML"
  default     = false
}

variable "nfs_file_share_size" {
  type        = number
  description = "NFS File Share size in GB"
  default     = 100
}

variable "create_vm_mounting_nfs" {
  type        = bool
  description = "Whether to create a VM which mounts this NFS"
  default     = false
}
EOF
   fi

   # Repair a prior bad patch that inserted NFS inputs into module.cdp_deploy.
   sed -i '/^[[:space:]]*# HoL automation: premium NFS/d' "$main_tf"
   sed -i '/^[[:space:]]*create_azure_cml_nfs[[:space:]]*=/d' "$main_tf"
   sed -i '/^[[:space:]]*nfs_file_share_size[[:space:]]*=/d' "$main_tf"
   sed -i '/^[[:space:]]*create_vm_mounting_nfs[[:space:]]*=/d' "$main_tf"

   if ! awk '/module "cdp_azure_prereqs"/,/^[}]/{if(/create_azure_cml_nfs/) found=1} END{exit found?0:1}' "$main_tf"; then
      sed -i '/cdp_delegated_subnet_names = var.cdp_delegated_subnet_names/a\
\
  # HoL automation: NFS for CAI in CDP VNet/RG (premium file share + private endpoints)\
  create_azure_cml_nfs   = var.create_azure_cml_nfs\
  nfs_file_share_size    = var.nfs_file_share_size\
  create_vm_mounting_nfs = var.create_vm_mounting_nfs' "$main_tf"
   fi

   if ! grep -q "nfs_file_share_url" "$outputs_tf"; then
      cat <<'EOF' >>"$outputs_tf"
output "nfs_file_share_url" {
  description = "NFS file share URL for CAI"
  value       = module.cdp_azure_prereqs.nfs_file_share_url
}
output "nfs_storage_account_name" {
  description = "Premium NFS storage account name for CAI"
  value       = module.cdp_azure_prereqs.nfs_storage_account_name
}
output "nfs_existing_nfs_mount" {
  description = "NFS mount path for CAI workspace provisioning (nfs:// format)"
  value = (
    module.cdp_azure_prereqs.nfs_storage_account_name != null &&
    module.cdp_azure_prereqs.nfs_file_share_url != null
  ) ? format(
    "nfs://%s.file.core.windows.net:/%s/%s",
    module.cdp_azure_prereqs.nfs_storage_account_name,
    module.cdp_azure_prereqs.nfs_storage_account_name,
    trimprefix(
      module.cdp_azure_prereqs.nfs_file_share_url,
      format("https://%s.file.core.windows.net/", module.cdp_azure_prereqs.nfs_storage_account_name)
    )
  ) : null
}
EOF
   fi
}

cai_workbench_name() {
   echo "${workshop_name}-cai-ws"
}

# Parse Azure Files share name from terraform/azurerm share URL (not a hostname).
extract_nfs_share_name_from_url() {
   local share_url="$1"
   local share_name=""

   [[ -n "$share_url" ]] || return 1

   if [[ "$share_url" == *"file.core.windows.net/"* ]]; then
      share_name="${share_url#*file.core.windows.net/}"
   elif [[ "$share_url" == nfs://* ]]; then
      share_name="${share_url#*:/}"
      share_name="${share_name#*/}"
   else
      share_name="${share_url##*/}"
   fi
   share_name="${share_name%%/*}"
   share_name="${share_name%%\?*}"
   [[ -n "$share_name" && "$share_name" != *"file.core.windows.net"* ]] || return 1
   echo "$share_name"
}

# Resolve storage account + share for NFS export /{account}/{share}.
resolve_cai_nfs_export_components() {
   local mount_path="${1:-${CAI_EXISTING_NFS:-}}"
   local workbench_name nfs_export

   CAI_NFS_EXPORT_STORAGE_ACCOUNT="${CAI_NFS_STORAGE_ACCOUNT:-}"
   CAI_NFS_EXPORT_SHARE_NAME="${CAI_NFS_SHARE_NAME:-}"

   if [[ -n "${CAI_NFS_EXPORT_STORAGE_ACCOUNT:-}" && -n "${CAI_NFS_EXPORT_SHARE_NAME:-}" ]]; then
      return 0
   fi

   [[ -n "$mount_path" ]] || return 1
   workbench_name=$(cai_workbench_name)
   if [[ "$mount_path" == *"/${workbench_name}" ]]; then
      mount_path="${mount_path%/${workbench_name}}"
   fi

   nfs_export="${mount_path#*:/}"
   CAI_NFS_EXPORT_STORAGE_ACCOUNT="${nfs_export%%/*}"
   CAI_NFS_EXPORT_SHARE_NAME="${nfs_export#*/}"
   CAI_NFS_EXPORT_SHARE_NAME="${CAI_NFS_EXPORT_SHARE_NAME%%/*}"
   [[ -n "$CAI_NFS_EXPORT_STORAGE_ACCOUNT" && -n "$CAI_NFS_EXPORT_SHARE_NAME" ]] || return 1
   [[ "$CAI_NFS_EXPORT_SHARE_NAME" != *"file.core.windows.net"* ]] || return 1
}

# Build nfs:// mount path for Azure Files NFS (Cloudera CAI format).
# Optional third argument appends a per-workbench subdirectory on the share.
build_cai_existing_nfs_mount() {
   local storage_account="$1"
   local share_url="$2"
   local workbench_subdir="${3:-}"
   local share_name=""
   local mount_path=""

   [[ -n "$storage_account" && -n "$share_url" ]] || return 1

   share_name=$(extract_nfs_share_name_from_url "$share_url") || return 1

   mount_path="nfs://${storage_account}.file.core.windows.net:/${storage_account}/${share_name}"
   if [[ -n "$workbench_subdir" ]]; then
      mount_path="${mount_path}/${workbench_subdir}"
   fi
   echo "$mount_path"
}

# Ensure CAI_EXISTING_NFS includes the dedicated workbench subdirectory
# (e.g. nfs://acct.file.core.windows.net:/acct/share/whreply-cai-ws).
# Safe to call on every deploy/re-run; only appends when missing.
finalize_cai_nfs_mount_path() {
   local workbench_name
   workbench_name=$(cai_workbench_name)

   [[ -n "${CAI_EXISTING_NFS:-}" ]] || return 1
   if [[ "$CAI_EXISTING_NFS" != *"/${workbench_name}" ]]; then
      CAI_EXISTING_NFS="${CAI_EXISTING_NFS%/}/${workbench_name}"
      export CAI_EXISTING_NFS
   fi
}

# Create workbench NFS subdirectory and chown 8536:8536 (Cloudera cdsW user).
# Re-run safe: skips when the directory already exists with uid/gid 8536:8536; fixes wrong ownership.
prepare_cai_nfs_workbench_mount() {
   local workbench_name storage_account share_name mount_path
   local keycloak_host pem_path remote_rc

   should_provision_cai_nfs || return 0
   [[ -n "${CAI_EXISTING_NFS:-}" ]] || return 0
   finalize_cai_nfs_mount_path

   workbench_name=$(cai_workbench_name)
   mount_path="$CAI_EXISTING_NFS"
   resolve_cai_nfs_export_components "$mount_path" || \
      hol_fail "Could not parse CAI NFS export for workbench prep: $mount_path"
   storage_account="$CAI_NFS_EXPORT_STORAGE_ACCOUNT"
   share_name="$CAI_NFS_EXPORT_SHARE_NAME"

   keycloak_host=$(resolve_keycloak_server_ip optional || true)
   [[ -n "${keycloak_host:-}" ]] || hol_fail \
      "CAI NFS workbench prep requires Keycloak VM in the CDP VNet (PROVISION_KEYCLOAK=yes). Or manually mkdir/chown 8536:8536 on .../${workbench_name}."

   pem_path="/userconfig/.${workshop_name}/${ssh_key_name}.pem"
   if [[ ! -f "$pem_path" && -f "/userconfig/${ssh_key_name}.pem" ]]; then
      pem_path="/userconfig/${ssh_key_name}.pem"
   fi
   [[ -f "$pem_path" ]] || hol_fail "SSH key not found for CAI NFS prep: $pem_path"

   hol_subsection "Preparing CAI NFS workbench directory (${workbench_name})" "📁"
   hol_kv "NFS mount path" "$mount_path"
   hol_kv "Prep host" "$keycloak_host"

   remote_rc=0
   ssh -i "$pem_path" \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=30 \
      -o BatchMode=yes \
      "ubuntu@${keycloak_host}" \
      "sudo bash -s" -- "$storage_account" "$share_name" "$workbench_name" <<'EOF' || remote_rc=$?
set -euo pipefail
STORAGE_ACCOUNT="$1"
SHARE_NAME="$2"
WORKBENCH_NAME="$3"
MOUNT_BASE="/mnt/cai-nfs-${SHARE_NAME}"
WB_PATH="${MOUNT_BASE}/${WORKBENCH_NAME}"
NFS_SERVER="${STORAGE_ACCOUNT}.file.core.windows.net"
NFS_EXPORT="/${STORAGE_ACCOUNT}/${SHARE_NAME}"
CAI_UID=8536
CAI_GID=8536

if ! dpkg -s nfs-common >/dev/null 2>&1; then
   export DEBIAN_FRONTEND=noninteractive
   apt-get update -qq
   apt-get install -y -qq nfs-common
fi

mkdir -p "$MOUNT_BASE"
if ! mountpoint -q "$MOUNT_BASE"; then
   mount -t nfs -o vers=4.1,minorversion=1,sec=sys "${NFS_SERVER}:${NFS_EXPORT}" "$MOUNT_BASE"
fi

cleanup() {
   if mountpoint -q "$MOUNT_BASE"; then
      umount "$MOUNT_BASE" || true
   fi
}
trap cleanup EXIT

if [[ -d "$WB_PATH" ]]; then
   owner=$(stat -c '%u:%g' "$WB_PATH")
   if [[ "$owner" == "${CAI_UID}:${CAI_GID}" ]]; then
      echo "CAI NFS workbench directory already prepared (${WORKBENCH_NAME}, ${owner})"
      exit 0
   fi
   echo "CAI NFS workbench directory exists with ownership ${owner}; setting ${CAI_UID}:${CAI_GID}"
   chown "${CAI_UID}:${CAI_GID}" "$WB_PATH"
   exit 0
fi

mkdir -p "$WB_PATH"
chown "${CAI_UID}:${CAI_GID}" "$WB_PATH"
echo "Created CAI NFS workbench directory ${WORKBENCH_NAME} with ownership ${CAI_UID}:${CAI_GID}"
EOF

   [[ $remote_rc -eq 0 ]] || \
      hol_fail "CAI NFS workbench prep failed on ${keycloak_host}. Ensure Keycloak VM can reach Azure Files NFS private endpoints."

   hol_ok "CAI NFS workbench directory ready: ${mount_path}"
}

load_cdp_subnet_outputs_from_terraform() {
   local azure_tf_dir="/userconfig/.${workshop_name}/cdp-tf-quickstarts/azure"
   local public_subnets private_subnets

   [[ -d "$azure_tf_dir" ]] || return 1
   cd "$azure_tf_dir" || return 1

   public_subnets=$(terraform output -json azure_cdp_gateway_subnet_names 2>/dev/null | jq -c '.[0:3]' || true)
   private_subnets=$(terraform output -json azure_cdp_subnet_names 2>/dev/null | jq -c '.[0:3]' || true)
   [[ -z "$public_subnets" || "$public_subnets" == "null" ]] && return 1
   [[ -z "$private_subnets" || "$private_subnets" == "null" ]] && return 1

   export ENV_PUBLIC_SUBNETS="$public_subnets"
   export ENV_PRIVATE_SUBNETS="$private_subnets"
}

load_cai_nfs_from_terraform() {
   local azure_tf_dir="/userconfig/.${workshop_name}/cdp-tf-quickstarts/azure"

   [[ -d "$azure_tf_dir" ]] || return 1
   cd "$azure_tf_dir" || return 1

   NFS_FILE_SHARE_URL=$(terraform output -raw nfs_file_share_url 2>/dev/null || true)
   CAI_NFS_STORAGE_ACCOUNT=$(terraform output -raw nfs_storage_account_name 2>/dev/null || true)
   CAI_NFS_SHARE_NAME=$(extract_nfs_share_name_from_url "$NFS_FILE_SHARE_URL" 2>/dev/null || true)
   CAI_EXISTING_NFS=$(build_cai_existing_nfs_mount "$CAI_NFS_STORAGE_ACCOUNT" "$NFS_FILE_SHARE_URL" 2>/dev/null || true)

   if [[ -n "${CAI_EXISTING_NFS:-}" ]]; then
      finalize_cai_nfs_mount_path
      export CAI_EXISTING_NFS CAI_NFS_STORAGE_ACCOUNT CAI_NFS_SHARE_NAME NFS_FILE_SHARE_URL
      return 0
   fi
   return 1
}

# Cloudera prereqs passes all CDP subnets to terraform-azure-nfs (one PE per subnet).
# HoL CAI needs only one workbench subnet — use the first private subnet.
patch_cdp_prereqs_nfs_single_private_endpoint() {
   local azure_tf_dir="$1"
   local prereqs_main
   prereqs_main=$(find "${azure_tf_dir}/.terraform/modules" -path '*/terraform-cdp-azure-pre-reqs/main.tf' 2>/dev/null | head -1)
   [[ -z "$prereqs_main" ]] && return 0
   if grep -q 'HoL: single NFS private endpoint' "$prereqs_main"; then
      return 0
   fi
   sed -i 's/nfs_private_endpoint_target_subnet_names = local.cdp_subnet_names/nfs_private_endpoint_target_subnet_names = [local.cdp_subnet_names[0]] # HoL: single NFS private endpoint for first CAI workbench subnet/' "$prereqs_main"
}

append_cdp_nfs_tf_args() {
   local -n tf_args=$1
   local enable_nfs=false
   if should_provision_cai_nfs || cdp_nfs_enabled_in_state; then
      enable_nfs=true
   fi
   if [[ "$enable_nfs" == true ]]; then
      tf_args+=(
         -var "create_azure_cml_nfs=true"
         -var "nfs_file_share_size=${nfs_file_share_size:-100}"
         -var "create_vm_mounting_nfs=false"
      )
   fi
}

# Function to provision CDP Environment.
provision_cdp() {
   hol_banner "Provisioning CDP environment" "☁️"
   sleep 10
   USER_NAMESPACE=$workshop_name
   mkdir -p /userconfig/.$USER_NAMESPACE
   local quickstart_dir="/userconfig/.$USER_NAMESPACE/cdp-tf-quickstarts"
   local azure_tf_dir="${quickstart_dir}/azure"

   sync_cdp_tf_quickstarts "${quickstart_dir}" "azure"

   if [[ ! -d "${azure_tf_dir}" || ! -f "${azure_tf_dir}/variables.tf" || ! -f "${azure_tf_dir}/main.tf" ]]; then
      hol_fail "Azure Terraform quickstart files are missing under ${azure_tf_dir}. Check TF_QUICKSTART_VERSION=${TF_QUICKSTART_VERSION}."
   fi

   cd "${azure_tf_dir}" || hol_fail "Unable to enter Azure Terraform directory: ${azure_tf_dir}"

   # Convert comma-separated IPs into properly quoted Terraform list elements
   cdp_cidr=$(build_cdp_ingress_cidr_tf_list)

   #Adding outputs in quickstart outputs.tf
   file="outputs.tf"

   # Check if the public subnet output already exists
   public_subnet=$(grep "azure_cdp_gateway_subnet_names" "$file")

   # Check if the private subnet output already exists
   private_subnet=$(grep "azure_cdp_subnet_names" "$file")

   # Check if the bucket_name output already exists
   bucket_name=$(grep "azure_log_storage_container" "$file")

   vnet_name_output=$(grep "azure_vnet_name" "$file")
   network_rg_output=$(grep "azure_network_resource_group_name" "$file")

   # Append the public subnet output if it does not exist
   if [ -z "$public_subnet" ]; then
      cat <<EOF >>"$file"
output "azure_cdp_gateway_subnet_names" {
  value = module.cdp_azure_prereqs.azure_cdp_gateway_subnet_names
}
EOF
   fi
   # Append the private subnet output if it does not exist
   if [ -z "$private_subnet" ]; then
      cat <<EOF >>"$file"
output "azure_cdp_subnet_names" {
  value = module.cdp_azure_prereqs.azure_cdp_subnet_names
}
EOF
   fi
   # Append the bucket_name output if it does not exist
   if [ -z "$bucket_name" ]; then
      cat <<EOF >>"$file"
output "log_storage_container_name" {
  description = "Azure log storage container name"
  value       = module.cdp_azure_prereqs.azure_log_storage_container
}
output "log_storage_account_name" {
  description = "Azure log storage account name"
  value       = module.cdp_azure_prereqs.azure_log_storage_account
}
output "azure_resource_group_name" {
  description = "Azure resource group for CDP resources"
  value       = module.cdp_azure_prereqs.azure_cdp_resource_group_name
}
output "azure_data_storage_account" {
  description = "Azure datalake storage account name"
  value       = module.cdp_azure_prereqs.azure_data_storage_account
}
EOF
   fi
   if [ -z "$vnet_name_output" ]; then
      cat <<EOF >>"$file"
output "azure_vnet_name" {
  description = "Azure Virtual Network Name"
  value       = module.cdp_azure_prereqs.azure_vnet_name
}
EOF
   fi
   if [ -z "$network_rg_output" ]; then
      cat <<EOF >>"$file"
output "azure_network_resource_group_name" {
  description = "Azure resource group containing the CDP VNet"
  value       = module.cdp_azure_prereqs.azure_network_resource_group_name
}
EOF
   fi
   if should_provision_cai_nfs; then
      hol_subsection "CDP Terraform: enable CAI NFS in prereqs module" "📁"
      hol_info "NFS is provisioned with CDP infra (same RG/VNet) — premium FileStorage, one private endpoint in the first CDP subnet, secure transfer disabled"
      patch_cdp_quickstart_for_cai_nfs "${azure_tf_dir}"
   fi
   terraform init
   if should_provision_cai_nfs; then
      patch_cdp_prereqs_nfs_single_private_endpoint "${azure_tf_dir}"
   fi

   # Default to empty map if ENV_TAGS not provided in configfile
   env_tags="${env_tags:-{}}"

   TFVARS_FILE="/tmp/env_tags_${workshop_name}.tfvars"

   if [[ -z "${ssh_public_key:-}" && -f "/userconfig/.${workshop_name}/${ssh_key_name}.pem" ]]; then
      export ssh_public_key=$(ssh-keygen -y -f "/userconfig/.${workshop_name}/${ssh_key_name}.pem")
   fi
   if [[ -z "${ssh_public_key:-}" ]]; then
      hol_fail "SSH public key is not set. Generate or mount an SSH key before provisioning CDP."
   fi

   if [[ "$env_tags" == "{}" ]]; then
      echo 'env_tags = {}' > "$TFVARS_FILE"
   else
      # Strip outer braces — use tr to remove ALL { and } then rebuild cleanly
      inner=$(echo "$env_tags" | tr -d '\r\n{}')
      # Build tfvars map
      echo 'env_tags = {' > "$TFVARS_FILE"
      IFS=',' read -ra pairs <<< "$inner"
      for pair in "${pairs[@]}"; do
         tag_key="${pair%%=*}"
         tag_val="${pair#*=}"
         echo "  \"${tag_key}\" = \"${tag_val}\"" >> "$TFVARS_FILE"
      done
      echo '}' >> "$TFVARS_FILE"
   fi

   {
      echo ''
      echo 'public_key_text = <<-EOT'
      echo "$ssh_public_key"
      echo 'EOT'
   } >> "$TFVARS_FILE"

   hol_subsection "Generated Terraform tfvars" "🏷️"
   hol_kv "Quickstart version" "$TF_QUICKSTART_VERSION"
   hol_kv "Terraform directory" "$(pwd)"
   cat "$TFVARS_FILE"

   local cdp_tf_apply_args=(
      -var "env_prefix=${workshop_name}"
      -var "azure_region=${azure_region}"
      -var "deployment_template=${deployment_template}"
      -var "ingress_extra_cidrs_and_ports={cidrs = [${cdp_cidr}],ports = [443, 22]}"
      -var "datalake_version=${datalake_version}"
      -var-file="${TFVARS_FILE}"
   )
   append_cdp_nfs_tf_args cdp_tf_apply_args

   export TF_INPUT=0

   hol_subsection "Running Terraform for CDP environment & datalake" "☁️"
   terraform apply --auto-approve "${cdp_tf_apply_args[@]}"

   if [ $? -ne 0 ]; then
      return 1
   fi

   assign_environment_base_roles
   hol_assign_pipeline_cdp_env_admin_roles || return 1

   cdp_provision_status=0
   if [ $cdp_provision_status -eq 0 ]; then
      export ENV_PUBLIC_SUBNETS=$(terraform output -json azure_cdp_gateway_subnet_names)
      export ENV_PRIVATE_SUBNETS=$(terraform output -json azure_cdp_subnet_names)

      hol_kv "Public subnets" "$ENV_PUBLIC_SUBNETS"
      hol_kv "Private subnets" "$ENV_PRIVATE_SUBNETS"

      ENV_PUBLIC_SUBNETS=$(terraform output -json azure_cdp_gateway_subnet_names | jq -c '.[0:3]')
      hol_info "First 3 public subnets (CDW/CDF): $ENV_PUBLIC_SUBNETS"
      ENV_PRIVATE_SUBNETS=$(terraform output -json azure_cdp_subnet_names | jq -c '.[0:3]')
      hol_info "First 3 private subnets (CDW/CDF): $ENV_PRIVATE_SUBNETS"

      export LOG_STORAGE_CONTAINER=$(terraform output -raw log_storage_container_name)
      export LOG_STORAGE_ACCOUNT=$(terraform output -raw log_storage_account_name)
      export DATA_STORAGE_ACCOUNT=$(terraform output -raw azure_data_storage_account 2>/dev/null || true)
      export AZURE_RESOURCE_GROUP=$(terraform output -raw azure_resource_group_name)

      if [[ -n "${DATA_STORAGE_ACCOUNT:-}" ]]; then
         hol_kv "Datalake storage account" "$DATA_STORAGE_ACCOUNT"
      fi

      if should_provision_cai_nfs; then
         if load_cai_nfs_from_terraform; then
            hol_kv "CAI NFS mount" "$CAI_EXISTING_NFS"
            hol_kv "CAI NFS storage account" "$CAI_NFS_STORAGE_ACCOUNT"
         else
            hol_warn "CAI NFS outputs are missing — CAI workspace provisioning will fail until NFS is created"
         fi
      fi

      # Count elements in ENV_PUBLIC_SUBNETS and ENV_PRIVATE_SUBNETS
      count_public=$(count_elements "$ENV_PUBLIC_SUBNETS")
      count_private=$(count_elements "$ENV_PRIVATE_SUBNETS")

      # echo -e "\nCounts:"
      # echo "ENV_PUBLIC_SUBNETS count: $count_public"
      # echo "ENV_PRIVATE_SUBNETS count: $count_private"

      # Using conditional expressions to assign values
      ENV_PUBLIC_SUBNETS=$([ "$count_public" -ge 1 ] && echo "$ENV_PUBLIC_SUBNETS" || echo "$ENV_PRIVATE_SUBNETS")
      ENV_PRIVATE_SUBNETS=$([ "$count_private" -ge 1 ] && echo "$ENV_PRIVATE_SUBNETS" || echo "$ENV_PUBLIC_SUBNETS")

      hol_kv "Final public subnets" "$ENV_PUBLIC_SUBNETS"
      hol_kv "Final private subnets" "$ENV_PRIVATE_SUBNETS"

      get_cdp_network_for_keycloak || hol_warn "Could not cache CDP network outputs for Keycloak — will retry before Keycloak provision"

      # Start Keycloak while Azure enhancements run (same pattern as AWS: KC boots during long CDP work).
      if [[ "${provision_keycloak:-no}" == "yes" ]]; then
         setup_keycloak_vm || return 1
      fi

      azure_enhancements #calling azure_enhancements function
      azure_enhancements_status=$?
      if [ $azure_enhancements_status -ne 0 ]; then
         hol_warn "Azure enhancements failed to apply — check logs for details"
      fi
      if [[ -n "${CDW_MANAGED_IDENTITY_ID:-}" ]]; then
         export CDW_MANAGED_IDENTITY_ID
      fi

      if [[ "${provision_keycloak:-no}" == "yes" ]]; then
         wait_for_keycloak_ready || return 1
      fi

      return 0
   else
      return 1
   fi

}

#Add enhancements
azure_enhancements() {
   hol_subsection "Adding Azure enhancements" "✨"
   USER_NAMESPACE=$workshop_name
   mkdir -p /userconfig/.$USER_NAMESPACE

   if [ ! -d "/userconfig/.$USER_NAMESPACE/azure_enhancements" ]; then
      cp -R "$ENHANCEMENTS_TF_CONFIG_DIR" "/userconfig/.$USER_NAMESPACE/"
   else
      for module_dir in "$ENHANCEMENTS_TF_CONFIG_DIR"*/; do
         module_name=$(basename "$module_dir")
         target_dir="/userconfig/.$USER_NAMESPACE/azure_enhancements/$module_name"
         if [ ! -d "$target_dir" ]; then
            cp -R "$module_dir" "/userconfig/.$USER_NAMESPACE/azure_enhancements/"
         else
            # Refresh module *.tf from image so prereq fixes apply without wiping .terraform state.
            cp -f "$module_dir"/*.tf "$target_dir/" 2>/dev/null || true
         fi
      done
   fi

   cd /userconfig/.$USER_NAMESPACE/azure_enhancements/storage_lifecycle
   terraform init
   terraform apply -auto-approve \
      -var="log_storage_account=$LOG_STORAGE_ACCOUNT" \
      -var="log_storage_container=$LOG_STORAGE_CONTAINER" \
      -var="resource_group_name=$AZURE_RESOURCE_GROUP" \
      -var="azure_region=$azure_region"

   hol_subsection "Granting datalake admin log container write access" "🔐"
   cd /userconfig/.$USER_NAMESPACE/azure_enhancements/dladmin_log_access
   terraform init
   terraform apply -auto-approve \
      -var="env_prefix=$workshop_name" \
      -var="log_storage_account=$LOG_STORAGE_ACCOUNT" \
      -var="log_storage_container=$LOG_STORAGE_CONTAINER" \
      -var="resource_group_name=$AZURE_RESOURCE_GROUP" \
      -var="azure_region=$azure_region"

   if should_apply_ai_registry_storage_access; then
      if ! resolve_datalake_storage_account; then
         hol_fail "Datalake storage account is not set. AI Registry requires Storage Blob roles on the datalake account."
      fi

      hol_subsection "Granting datalake storage access for AI Registry" "🤖"
      cd /userconfig/.$USER_NAMESPACE/azure_enhancements/ai_registry_storage_access
      terraform init
      terraform apply -auto-approve \
         -var="env_prefix=$workshop_name" \
         -var="data_storage_account=$DATA_STORAGE_ACCOUNT" \
         -var="resource_group_name=$AZURE_RESOURCE_GROUP" \
         -var="azure_region=$azure_region"
   fi

   if should_provision_cdw; then
      if ! resolve_datalake_storage_account; then
         hol_fail "Datalake storage account is not set. CDW identity requires Storage Blob Data Owner on the datalake account."
      fi

      hol_subsection "Provisioning CDW custom identity and role" "🏢"
      cd /userconfig/.$USER_NAMESPACE/azure_enhancements/cdw_custom_identity
      terraform init
      terraform apply -auto-approve \
         -var="env_prefix=$workshop_name" \
         -var="resource_group_name=$AZURE_RESOURCE_GROUP" \
         -var="data_storage_account=$DATA_STORAGE_ACCOUNT" \
         -var="azure_region=$azure_region"
      export CDW_MANAGED_IDENTITY_ID=$(terraform output -raw cdw_managed_identity_id)
      hol_kv "CDW managed identity" "$CDW_MANAGED_IDENTITY_ID"
   fi

   if should_provision_cde; then
      hol_subsection "Provisioning CDE custom identities" "🏢"
      cd /userconfig/.$USER_NAMESPACE/azure_enhancements/cde_custom_identity
      terraform init
      terraform apply -auto-approve \
         -var="env_prefix=$workshop_name" \
         -var="log_storage_account=$LOG_STORAGE_ACCOUNT" \
         -var="log_storage_container=$LOG_STORAGE_CONTAINER" \
         -var="resource_group_name=$AZURE_RESOURCE_GROUP" \
         -var="azure_region=$azure_region"
      export CDE_CLUSTER_MANAGED_IDENTITY_ID=$(terraform output -raw cde_cluster_managed_identity_id)
      export CDE_VC_MANAGED_IDENTITY_ID=$(terraform output -raw cde_vc_managed_identity_id)
      hol_kv "CDE cluster managed identity" "$CDE_CLUSTER_MANAGED_IDENTITY_ID"
      hol_kv "CDE VC managed identity" "$CDE_VC_MANAGED_IDENTITY_ID"
   fi
}

#--------------------------------------------------------------------------------------------------#
initialize_compute_cluster() {
   hol_subsection "Initializing compute cluster" "🖥️"
   USER_NAMESPACE=$workshop_name
   mkdir -p /userconfig/.$USER_NAMESPACE

   if [ ! -d "/userconfig/.$USER_NAMESPACE/$CAII_SCRIPTS_DIR" ]; then
      cp -R "$CAII_SCRIPTS_DIR" "/userconfig/.$USER_NAMESPACE/"
   fi
   cd /userconfig/.$USER_NAMESPACE/CAII

   chmod +x ./convert_v2_env.sh
   ./convert_v2_env.sh $ENV_PUBLIC_SUBNETS $workshop_name $local_ip

   #deploy Compute cluster
   chmod +x ./initialize_default_cluster.sh

   ./initialize_default_cluster.sh $workshop_name
}

provision_compute_cluster() {
hol_subsection "Provisioning compute cluster" "🖥️"
   USER_NAMESPACE=$workshop_name
   mkdir -p /userconfig/.$USER_NAMESPACE

   if [ ! -d "/userconfig/.$USER_NAMESPACE/$CAII_SCRIPTS_DIR" ]; then
      cp -R "$CAII_SCRIPTS_DIR" "/userconfig/.$USER_NAMESPACE/"
   fi
   cd /userconfig/.$USER_NAMESPACE/CAII

   #deploy Compute cluster
   chmod +x ./compute_cluster_deploy.sh

   ./compute_cluster_deploy.sh $workshop_name
}

enable_ai_registry() { 
  hol_subsection "Deploying AI Registry" "📦"
  USER_NAMESPACE=$workshop_name   
  cd /userconfig/.$USER_NAMESPACE/CAII

  environment_crn=$(cdp environments describe-environment --environment-name ${workshop_name}-cdp-env | jq -r .environment.crn)

  # Check if AI Registry exists and is already installed
  registry_status=$(cdp ml list-model-registries | jq -r --arg env_name "${workshop_name}-cdp-env" '
    .modelRegistries[]
    | select(.environmentName == $env_name)
    | .status
  ')

  if [[ "$registry_status" == "installation:finished" ]]; then
    echo "✅ AI Registry for environment '${workshop_name}-cdp-env' is already installed. Skipping creation."
    return
  else
    echo "🚀 Proceeding with AI Registry deployment"
    cdp ml create-model-registry \
      --environment-crn "$environment_crn" \
      --environment-name "${workshop_name}-cdp-env" \
      --use-public-load-balancer
  fi

  echo "⏳ Waiting for AI Registry installation to finish..."
  for i in {1..75}; do
    registry_status=$(cdp ml list-model-registries | jq -r --arg env_name "${workshop_name}-cdp-env" '
      .modelRegistries[]
      | select(.environmentName == $env_name)
      | .status
    ')

    echo "   ➤ Attempt $i: Status = $registry_status"

    # Normalize to lowercase for matching
    status_lower=$(echo "$registry_status" | tr '[:upper:]' '[:lower:]')

    if [[ "$status_lower" == "installation:finished" ]]; then
      echo "✅ AI Registry installation finished successfully."
      return
    elif [[ "$status_lower" == *"failed"* ]]; then
      echo "❌ AI Registry installation FAILED with status: $registry_status"
      exit 1
    fi

    sleep 60
  done

  echo "❌ Timeout Error: AI Registry did not reach 'installation:finished' state."
  exit 1
}

provision_caii_service_app() {
   USER_NAMESPACE=$workshop_name
   cd /userconfig/.$USER_NAMESPACE/CAII
   
   hol_subsection "Provisioning AI Inference service app" "🧠"
   
   #Update template for serving app
   chmod +x ./create_serving_app_input.sh
   ./create_serving_app_input.sh $workshop_name
   
   local env_name="${workshop_name}-cdp-env"
   caii_service_status=$(cdp ml list-ml-serving-apps | jq -r --arg env_name "$env_name" '
     .apps[]
     | select(.environmentName == $env_name)
     | .status
   ')

   if [[ "$caii_service_status" == "installation:finished" ]]; then
     echo "✅ CAII service for environment '${workshop_name}-cdp-env' is already installed. Skipping creation."
   else
     echo "🚀 Proceeding with CAII service deployment"
      # Create model endpoint
      cdp ml create-ml-serving-app --cli-input-json file://updated-serving-app-input.json
      sleep 60
   fi

   for i in {1..60}; do
     caii_service_status=$(cdp ml list-ml-serving-apps | jq -r --arg env_name "$env_name" '
      .apps[]
      | select(.environmentName == $env_name)
      | .status
     ')

     echo "   ➤ Attempt $i: Status = $caii_service_status"

   # Keep looping until status is 'installation:finished'
     if [[ "$caii_service_status" == "installation:finished" ]]; then
         echo "✅ Installation finished."
         break
     elif [[ "$caii_service_status" == "installation:failed" ]]; then
         echo "❌ Installation failed."
         exit 1
     fi

     sleep 45
   done  
}

provision_cai_inference() {
   hol_banner "Provisioning AI Inference (CAII)" "🧠"

  local env_name="${workshop_name}-cdp-env"

  # Step 1: Initialize compute cluster
  initialize_compute_cluster

  # Step 2: Provision compute cluster, AI registry and CAI workbench in parallel
  provision_compute_cluster &
  pid_compute=$!
  sleep 60

  enable_ai_registry &
  pid_ai_registry=$!

  deploy_single_data_service cai &
  pid_cai=$!

  wait $pid_compute
  status_compute=$?

  wait $pid_ai_registry
  status_ai_registry=$?

  wait $pid_cai
  status_cai=$?

  if [[ $status_compute -ne 0 || $status_ai_registry -ne 0 || $status_cai -ne 0 ]]; then
    echo "❌ Error: One or more provisioning steps failed."
    return 1
  fi

  # Step 3: Proceed to CAII service deployment
  provision_caii_service_app
}


destroy_cai_inference() {
   hol_subsection "Destroying AI Inference" "🧠"
   
   USER_NAMESPACE=$workshop_name
   cd /userconfig/.$USER_NAMESPACE/CAII

   # Delete ML Serving App first, extract CRN
   serving_app_crn=$(cdp ml list-ml-serving-apps | jq -r --arg env_name "${workshop_name}-cdp-env" '
     .apps[] | select(.environmentName == $env_name) | .appCrn
   ')

   if [[ -n "$serving_app_crn" ]]; then
     echo "🗑️ Deleting ML Serving App: $serving_app_crn"
     cdp ml delete-ml-serving-app --app-crn "$serving_app_crn"
   else
     echo "✅ No ML Serving App found"
   fi
   
   # Set the data service value for cleanup
   disable_single_data_service cai &
   pid_disable=$!
   sleep 30
   
   chmod +x ./destroy_caii_resources.sh
   ./destroy_caii_resources.sh $workshop_name
   
   # Wait for disable_data_services to complete before exiting
   wait $pid_disable
}
#--------------------------------------------------------------------------------------------------#

# Update the User Group.
update_cdp_user_group() {
   cdp iam update-group --group-name $workshop_name-az-cdp-user-group --sync-membership-on-user-login
}

# CDP environments sync-all-users can return 409 CONFLICT for USER_SYNC (e.g. after IAM user
# creation or assignCdpEnvAdminRoles.sh). The body may name usersync:<uuid> as running while
# get-environment-user-sync-state still shows UP_TO_DATE / COMPLETED for a different operation.
# Poll the id from the conflict body. Tunables: HOL_CDP_USER_SYNC_MAX_ATTEMPTS (12),
# HOL_CDP_USER_SYNC_RETRY_SLEEP_SEC (30), HOL_CDP_USER_SYNC_STALE_CONFLICT_SLEEP_SEC (5),
# HOL_CDP_USER_SYNC_WAIT_SEC (600), HOL_CDP_USER_SYNC_POLL_SEC (15).
# HOL_CDP_USER_SYNC_DEBUG=1 prints the full CDP error, HTTP request id, and status snapshot.
hol_cdp_user_sync_conflict() {
   local msg="$1"
   grep -q '409' <<<"$msg" || return 1
   grep -qi 'CONFLICT' <<<"$msg" || return 1
   grep -qE 'syncAllUsers|USER_SYNC' <<<"$msg"
}

hol_cdp_user_sync_conflict_request_id() {
   local msg="$1" id=""
   id=$(grep -oEi '(request[_ ]?id|Request Id)[:= ]+[A-Za-z0-9-]+' <<<"$msg" | head -1 | sed -E 's/.*[:= ]+//') || true
   [[ -n "$id" ]] && echo "$id"
}

hol_cdp_user_sync_error_summary() {
   local msg="$1" line
   while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      printf '%s' "$line"
      return 0
   done <<<"$msg"
   printf '409 CONFLICT (sync-all-users)'
}

hol_cdp_user_sync_state_snapshot() {
   local env_name="$1"
   local sync_state_json state op_id sync_status last_status

   sync_state_json=$(cdp environments get-environment-user-sync-state --environment-name "$env_name" 2>/dev/null || true)
   state=$(jq -r '.state // empty' <<<"$sync_state_json" 2>/dev/null)
   [[ "$state" == "null" ]] && state=""
   op_id=$(jq -r '.userSyncOperationId // empty' <<<"$sync_state_json" 2>/dev/null)
   [[ "$op_id" == "null" ]] && op_id=""
   sync_status=""
   if [[ -n "$op_id" ]]; then
      sync_status=$(cdp environments sync-status --operation-id "$op_id" 2>/dev/null | jq -r '.status // empty')
      [[ "$sync_status" == "null" ]] && sync_status=""
   fi
   last_status=$(cdp environments last-sync-status --environment "$env_name" 2>/dev/null | jq -r '.status // empty')
   [[ "$last_status" == "null" ]] && last_status=""

   hol_kv "CDP user-sync state (get-environment-user-sync-state)" "${state:-unknown}"
   [[ -n "$op_id" ]] && hol_kv "Latest user-sync operation id" "$op_id"
   [[ -n "$sync_status" ]] && hol_kv "Latest operation status (sync-status)" "$sync_status"
   [[ -n "$last_status" ]] && hol_kv "Last sync status (last-sync-status)" "$last_status"
}

# usersync:<uuid> from a 409 body (CRN or bare). Prefer the id nearest the word "running".
hol_cdp_user_sync_conflict_operation_id() {
   local msg="$1" flat="" line="" uuid="" off="" run_off="" best="" best_dist=999999 dist
   flat=$(printf '%s' "$msg" | tr '\n' ' ')
   run_off=$(printf '%s' "$flat" | grep -boEi 'running' | head -1 | cut -d: -f1 || true)
   while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      off=${line%%:*}
      uuid=$(printf '%s' "${line#*:}" | sed -E 's/^[Uu][Ss][Ee][Rr][Ss][Yy][Nn][Cc]://')
      if [[ -z "$run_off" ]]; then
         printf '%s\n' "$uuid"
         return 0
      fi
      if [[ $off -gt $run_off ]]; then
         dist=$((off - run_off))
      else
         dist=$((run_off - off))
      fi
      if [[ $dist -lt $best_dist ]]; then
         best_dist=$dist
         best=$uuid
      fi
   done < <(printf '%s' "$flat" | grep -boEi 'usersync:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' || true)
   [[ -n "$best" ]] && printf '%s\n' "$best"
}

hol_cdp_user_sync_debug_conflict() {
   local output="$1" env_name="$2" req_id="" err_summary=""
   [[ "${HOL_CDP_USER_SYNC_DEBUG:-0}" == "1" ]] || return 0
   err_summary=$(hol_cdp_user_sync_error_summary "$output")
   req_id=$(hol_cdp_user_sync_conflict_request_id "$output" || true)
   hol_warn "cdp environments sync-all-users returned 409 CONFLICT: ${err_summary}"
   [[ -n "$req_id" ]] && hol_info "CDP HTTP request id (not the user-sync operation id): ${req_id}"
   hol_cdp_user_sync_state_snapshot "$env_name"
}

hol_cdp_environment_user_sync_in_progress() {
   local env_name="$1"
   local state status op_id sync_status sync_state_json

   sync_state_json=$(cdp environments get-environment-user-sync-state --environment-name "$env_name" 2>/dev/null || true)
   state=$(jq -r '.state // empty' <<<"$sync_state_json" 2>/dev/null)
   [[ "$state" == "null" ]] && state=""

   case "$state" in
      SYNC_IN_PROGRESS) return 0 ;;
      UP_TO_DATE|STALE|SYNC_FAILED) return 1 ;;
   esac

   if [[ -n "$state" ]] && grep -qiE 'RUNNING|IN_PROGRESS|SYNCING|SYNC_IN_PROGRESS' <<<"$state"; then
      return 0
   fi
   if [[ -n "$state" ]] && grep -qiE 'COMPLETED|SUCCEEDED|SUCCESS|IDLE|READY|NOT_RUNNING|NONE' <<<"$state"; then
      return 1
   fi

   op_id=$(jq -r '.userSyncOperationId // empty' <<<"$sync_state_json" 2>/dev/null)
   [[ "$op_id" == "null" ]] && op_id=""
   if [[ -n "$op_id" ]]; then
      sync_status=$(cdp environments sync-status --operation-id "$op_id" 2>/dev/null | jq -r '.status // empty')
      [[ "$sync_status" == "null" ]] && sync_status=""
      if [[ -n "$sync_status" ]] && grep -qiE 'RUNNING|IN_PROGRESS|REQUESTED|PENDING' <<<"$sync_status"; then
         return 0
      fi
      if [[ -n "$sync_status" ]] && grep -qiE 'COMPLETED|SUCCEEDED|SUCCESS|FAILED|ERROR|REJECTED|TIMEDOUT' <<<"$sync_status"; then
         return 1
      fi
   fi

   status=$(cdp environments last-sync-status --environment "$env_name" 2>/dev/null | jq -r '.status // empty')
   [[ "$status" == "null" ]] && status=""
   if [[ -n "$status" ]] && grep -qiE 'RUNNING|IN_PROGRESS|REQUESTED|PENDING' <<<"$status"; then
      return 0
   fi
   return 1
}

hol_cdp_wait_for_environment_user_sync() {
   local env_name="$1"
   local max_wait_sec="${2:-${HOL_CDP_USER_SYNC_WAIT_SEC:-600}}"
   local quiet="${3:-}"
   local poll_sec="${HOL_CDP_USER_SYNC_POLL_SEC:-15}"
   local elapsed=0

   while [[ $elapsed -lt $max_wait_sec ]]; do
      if ! hol_cdp_environment_user_sync_in_progress "$env_name"; then
         return 0
      fi
      if [[ "$quiet" != "quiet" ]]; then
         hol_step "User sync in progress for '${env_name}' — waiting ${poll_sec}s..."
      fi
      sleep "$poll_sec"
      elapsed=$((elapsed + poll_sec))
   done
   hol_warn "Timed out after ${max_wait_sec}s waiting for user sync on '${env_name}'"
   return 1
}

# 0 = still active, 1 = terminal, 2 = status unknown (do not treat as "no active sync").
hol_cdp_user_sync_operation_liveness() {
   local op_id="$1" status=""
   status=$(cdp environments sync-status --operation-id "$op_id" 2>/dev/null | jq -r '.status // empty' 2>/dev/null || true)
   [[ "$status" == "null" ]] && status=""
   if [[ -z "$status" ]]; then
      return 2
   fi
   if grep -qiE 'RUNNING|IN_PROGRESS|REQUESTED|PENDING|SYNCING' <<<"$status"; then
      return 0
   fi
   if grep -qiE 'COMPLETED|SUCCEEDED|SUCCESS|FAILED|ERROR|REJECTED|TIMEDOUT|TIMED_OUT|CANCELLED|CANCELED' <<<"$status"; then
      return 1
   fi
   return 2
}

# Poll the usersync id named by the 409. Quiet: the caller already printed one waiting line.
# Unknown status keeps waiting — the 409 said this op is running, even if latest sync-status
# is a different COMPLETED operation. Returns 0 when the operation is terminal, 1 on timeout.
hol_cdp_wait_for_user_sync_operation() {
   local op_id="$1"
   local max_wait_sec="${2:-${HOL_CDP_USER_SYNC_WAIT_SEC:-600}}"
   local poll_sec="${HOL_CDP_USER_SYNC_POLL_SEC:-15}"
   local elapsed=0 live=0

   while [[ $elapsed -lt $max_wait_sec ]]; do
      live=0
      hol_cdp_user_sync_operation_liveness "$op_id" || live=$?
      if [[ $live -eq 1 ]]; then
         return 0
      fi
      sleep "$poll_sec"
      elapsed=$((elapsed + poll_sec))
   done
   hol_warn "Timed out after ${max_wait_sec}s waiting for user sync ${op_id}"
   return 1
}

hol_cdp_sync_all_users_resilient() {
   local env_name="$1"
   local max_attempts="${HOL_CDP_USER_SYNC_MAX_ATTEMPTS:-12}"
   local retry_sleep="${HOL_CDP_USER_SYNC_RETRY_SLEEP_SEC:-30}"
   local wait_max_sec="${HOL_CDP_USER_SYNC_WAIT_SEC:-600}"
   local attempt=1 output exit_status

   while [[ $attempt -le $max_attempts ]]; do
      output=$(cdp environments sync-all-users --environment-names "$env_name" 2>&1)
      exit_status=$?
      if [[ $exit_status -eq 0 ]]; then
         hol_cdp_wait_for_environment_user_sync "$env_name" "$wait_max_sec" \
            || hol_warn "User sync wait incomplete for '${env_name}' — continuing provision"
         hol_ok "CDP user sync completed for environment '${env_name}'"
         return 0
      fi
      if hol_cdp_user_sync_conflict "$output"; then
         local running_op="" stale_sleep="${HOL_CDP_USER_SYNC_STALE_CONFLICT_SLEEP_SEC:-5}"
         running_op=$(hol_cdp_user_sync_conflict_operation_id "$output" || true)
         hol_cdp_user_sync_debug_conflict "$output" "$env_name"
         if [[ -n "$running_op" ]]; then
            # Do not consult latest sync-status here: it can be a different COMPLETED op.
            hol_warn "User sync already running (${running_op}) — waiting"
            hol_step "CDP user sync retry ${attempt}/${max_attempts}"
            hol_cdp_wait_for_user_sync_operation "$running_op" "$wait_max_sec" || true
            sleep "$retry_sleep"
         elif hol_cdp_environment_user_sync_in_progress "$env_name"; then
            hol_warn "User sync already running — waiting"
            hol_step "CDP user sync retry ${attempt}/${max_attempts}"
            hol_cdp_wait_for_environment_user_sync "$env_name" "$wait_max_sec" quiet || true
            sleep "$retry_sleep"
         else
            hol_warn "User sync conflict — retrying"
            hol_step "CDP user sync retry ${attempt}/${max_attempts}"
            sleep "$stale_sleep"
         fi
         attempt=$((attempt + 1))
         continue
      fi
      hol_fail "cdp environments sync-all-users failed for '${env_name}': $output"
   done
   hol_fail "cdp environments sync-all-users for '${env_name}' still conflicting after ${max_attempts} attempts: ${output}"
}

terraform_output_benign_destroy_error() {
   grep -qiE 'ResourceNotFound|Request_ResourceNotFound|was not found|does not exist|could not be found|does not exist or one of its queried reference-property objects are not present|No password credential found|404 \(404 Not Found\)|unexpected status 404|status 404|StatusCode=404' <<<"$1"
}

terraform_output_resource_not_found() {
   terraform_output_benign_destroy_error "$1"
}

terraform_benign_destroy_summary() {
   local block="$1"
   if grep -qi 'password credential' <<<"$block"; then
      echo "Entra ID app password already removed — continuing destroy"
   elif grep -qi 'Service Principal' <<<"$block"; then
      echo "Entra ID service principal already deleted — continuing destroy"
   else
      echo "Resource already deleted or does not exist in Azure — continuing destroy"
   fi
}

# Replace Terraform error boxes for already-deleted resources with a skip message.
terraform_filter_benign_destroy_output() {
   local in_block=0 buffer="" line
   while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == "╷" ]]; then
         in_block=1
         buffer="$line"
         continue
      fi
      if [[ $in_block -eq 1 ]]; then
         buffer="${buffer}"$'\n'"${line}"
         if [[ "$line" == "╵" ]]; then
            if terraform_output_benign_destroy_error "$buffer"; then
               hol_skip "$(terraform_benign_destroy_summary "$buffer")"
            else
               printf '%s\n' "$buffer"
            fi
            in_block=0
            buffer=""
         fi
         continue
      fi
      printf '%s\n' "$line"
   done
   [[ -n "$buffer" ]] && printf '%s\n' "$buffer"
}

terraform_output_resource_addresses() {
   grep -oE 'with [^,]+' <<<"$1" | sed 's/^with //' | sort -u
}

azuread_app_password_gone_in_azure() {
   local addr="$1" app_id key_id
   app_id=$(terraform state show -no-color "$addr" 2>/dev/null | awk -F' = ' '/^[[:space:]]*application_id / { print $2; exit }' | tr -d '" ')
   key_id=$(terraform state show -no-color "$addr" 2>/dev/null | awk -F' = ' '/^[[:space:]]*key_id / { print $2; exit }' | tr -d '" ')
   [[ -z "$app_id" || -z "$key_id" ]] && return 1
   ! az ad app credential list --id "$app_id" --query "[?keyId=='${key_id}']" -o tsv 2>/dev/null | grep -q .
}

azuread_service_principal_gone_in_azure() {
   local addr="$1" lookup_id
   lookup_id=$(terraform state show -no-color "$addr" 2>/dev/null | awk -F' = ' '/^[[:space:]]*object_id / { print $2; exit }' | tr -d '" ')
   [[ -z "$lookup_id" ]] && lookup_id=$(terraform state show -no-color "$addr" 2>/dev/null | awk -F' = ' '/^[[:space:]]*client_id / { print $2; exit }' | tr -d '" ')
   [[ -z "$lookup_id" ]] && return 1
   ! az ad sp show --id "$lookup_id" >/dev/null 2>&1
}

# Drop one address from state only when Azure confirms it is already gone (never deletes in Azure).
remove_gone_resource_from_state() {
   local addr="$1"
   [[ -z "$addr" ]] && return 1
   if [[ "$addr" == *azuread_application_password* ]]; then
      azuread_app_password_gone_in_azure "$addr" || return 1
   elif [[ "$addr" == *azuread_service_principal* ]]; then
      azuread_service_principal_gone_in_azure "$addr" || return 1
   fi
   hol_skip "Resource already gone in Azure — updating Terraform state only: ${addr}"
   terraform state rm "$addr" >/dev/null 2>&1
}

remove_stale_resources_from_terraform_output() {
   local output="$1"
   local addr removed=0

   if ! terraform_output_benign_destroy_error "$output"; then
      return 1
   fi

   # Only the exact resource Terraform failed on (`with ...` line) — does not touch anything else.
   while IFS= read -r addr; do
      [[ -z "$addr" ]] && continue
      hol_skip "Resource already gone in Azure — updating Terraform state only: ${addr}"
      terraform state rm "$addr" >/dev/null 2>&1 && removed=1
   done < <(terraform_output_resource_addresses "$output")

   # Fallback: only remove Entra ID entries verified absent (never bulk-drop live resources).
   if [[ $removed -eq 0 ]] && grep -qi 'Deleting Service Principal' <<<"$output"; then
      while IFS= read -r addr; do
         remove_gone_resource_from_state "$addr" && removed=1
      done < <(terraform state list 2>/dev/null | grep 'azuread_service_principal' || true)
   fi
   if [[ $removed -eq 0 ]] && grep -qi 'password credential' <<<"$output"; then
      while IFS= read -r addr; do
         remove_gone_resource_from_state "$addr" && removed=1
      done < <(terraform state list 2>/dev/null | grep 'azuread_application_password' || true)
   fi

   [[ $removed -eq 1 ]] && return 0
   return 1
}

# Azure 404 / ResourceNotFound during refresh means the resource is already gone — drop it from state.
repair_cdp_missing_resources_in_state() {
   local -a tf_args=("$@")
   local max_passes=50
   local pass=0 output status log

   if ! terraform state list 2>/dev/null | grep -q .; then
      return 0
   fi

   while [[ $pass -lt $max_passes ]]; do
      pass=$((pass + 1))
      log=$(mktemp)
      hol_step "Reconciling Terraform state with Azure (${pass}/${max_passes})..."
      terraform refresh "${tf_args[@]}" 2>&1 | tee "$log"
      status=${PIPESTATUS[0]}
      output=$(cat "$log")
      rm -f "$log"
      if [[ $status -eq 0 ]]; then
         return 0
      fi
      if remove_stale_resources_from_terraform_output "$output"; then
         continue
      fi
      return 1
   done
   hol_warn "Stopped after ${max_passes} stale-resource repairs; Terraform state may still be inconsistent"
   return 1
}

# Backwards-compatible alias (older image layers called this name).
repair_cdp_stale_storage_in_state() {
   repair_cdp_missing_resources_in_state "$@"
}

run_cdp_terraform_destroy() {
   local -n destroy_args=$1
   local max_attempts=50 attempt=0 output status log

   # Let Terraform drive destroy order; only reconcile state after a benign 404/400 on retry.
   while [[ $attempt -lt $max_attempts ]]; do
      attempt=$((attempt + 1))
      log=$(mktemp)
      hol_step "Running terraform destroy (${attempt}/${max_attempts})..."
      terraform destroy -refresh=false --auto-approve "${destroy_args[@]}" 2>&1 | tee "$log" | terraform_filter_benign_destroy_output
      status=${PIPESTATUS[0]}
      output=$(cat "$log")
      rm -f "$log"
      [[ $status -eq 0 ]] && return 0
      if remove_stale_resources_from_terraform_output "$output"; then
         hol_ok "Terraform state reconciled — retrying destroy"
         hol_info "Terraform will continue destroying remaining resources in dependency order"
         continue
      fi
      return $status
   done
   return 1
}

#--------------------------------------------------------------------------------------------------#
# Function to destroy CDP Environment.
destroy_cdp() {
   USER_NAMESPACE=$workshop_name
   hol_banner "Destroying CDP environment infrastructure" "🗑️"
   local azure_tf_dir="/userconfig/.$USER_NAMESPACE/cdp-tf-quickstarts/azure"
   if [[ ! -d "${azure_tf_dir}" || ! -f "${azure_tf_dir}/variables.tf" ]]; then
      hol_skip "Terraform state not found — skipping CDP terraform destroy"
      return 0
   fi
   cd "${azure_tf_dir}" || hol_fail "Unable to enter Azure Terraform directory: ${azure_tf_dir}"
   cdp_cidr=$(build_cdp_ingress_cidr_tf_list)

   if [[ -z "${ssh_public_key:-}" && -f "/userconfig/.${workshop_name}/${ssh_key_name}.pem" ]]; then
      export ssh_public_key=$(ssh-keygen -y -f "/userconfig/.${workshop_name}/${ssh_key_name}.pem")
   fi
   terraform init
   if should_provision_cai_nfs || cdp_nfs_enabled_in_state; then
      patch_cdp_quickstart_for_cai_nfs "${azure_tf_dir}"
      patch_cdp_prereqs_nfs_single_private_endpoint "${azure_tf_dir}"
   fi
   local cdp_tf_destroy_args=(
      -var "env_prefix=${workshop_name}"
      -var "azure_region=${azure_region}"
      -var "public_key_text=${ssh_public_key:-placeholder}"
      -var "deployment_template=${deployment_template}"
      -var "ingress_extra_cidrs_and_ports={cidrs = [${cdp_cidr}],ports = [443, 22]}"
   )
   append_cdp_nfs_tf_args cdp_tf_destroy_args
   export TF_INPUT=0
   hol_info "Destroying CDP Terraform resources (already deleted or missing Azure resources are removed from state)"
   run_cdp_terraform_destroy cdp_tf_destroy_args
   cdp_destroy_status=$?
   if [ "${cdp_destroy_status:-1}" -eq 0 ]; then
      rm -rf /userconfig/.$USER_NAMESPACE/cdp-tf-quickstarts/
      return 0
   else
      return 1
   fi
}
#--------------------------------------------------------------------------------------------------#
# Function to destroy Complete HOL Infrastructure.
destroy_hol_infra() {
   USER_NAMESPACE=$workshop_name
   keycloak_destroy_status=0
   cdp_destroy_status=0
   if [[ "$provision_keycloak" == "yes" ]]; then
      destroy_keycloak
      keycloak_destroy_status=$?
   fi
   if [[ "$keycloak_destroy_status" -eq 0 ]]; then
      destroy_cdp
      cdp_destroy_status=$?
   fi

   if [[ "$cdp_destroy_status" -eq 0 && "$keycloak_destroy_status" -eq 0 ]]; then
      if [[ -f /userconfig/.$USER_NAMESPACE/keypair_gen/keypair_generated.flag && "$(cat /userconfig/.$USER_NAMESPACE/keypair_gen/keypair_generated.flag)" == "true" ]]; then
         destroy_keypair
      fi
      rm -rf "/userconfig/.$USER_NAMESPACE"
      rm -rf "/userconfig/$workshop_name.txt"
      return 0
   else
      return 1
   fi
}

#--------------------------------------------------------------------------------------------------#
workshop_output_file() {
   echo "/userconfig/${workshop_name}.txt"
}

workshop_services_include() {
   local service="$1"
   local csv
   csv=$(hol_enabled_data_services_csv)
   [[ ",${csv}," == *",${service},"* ]]
}

append_workshop_output_section() {
   local title="$1"
   local out
   out="$(workshop_output_file)"
   {
      echo ""
      echo "==============================================================="
      echo "     ${title}"
      echo "==============================================================="
   } >>"$out"
}

write_workshop_cdp_outputs() {
   local out
   out="$(workshop_output_file)"
   append_workshop_output_section "CDP / Azure Infrastructure: ${workshop_name}"
   {
      echo "Generated (UTC): $(date -u +"%Y-%m-%d %H:%M:%S")"
      echo "CDP Environment: ${workshop_name}-cdp-env"
      echo "Azure Region: ${azure_region:-n/a}"
      echo "Azure Resource Group: ${AZURE_RESOURCE_GROUP:-n/a}"
      echo "Datalake Storage Account: ${DATA_STORAGE_ACCOUNT:-n/a}"
      echo "Log Storage Account: ${LOG_STORAGE_ACCOUNT:-n/a}"
      echo "Log Storage Container: ${LOG_STORAGE_CONTAINER:-n/a}"
      echo "CDP Console: https://console.cdp.cloudera.com/"
   } >>"$out"
   hol_ok "CDP outputs appended to ${out}"
}

write_workshop_data_service_outputs() {
   local out
   out="$(workshop_output_file)"
   append_workshop_output_section "Data Services & Identities: ${workshop_name}"
   {
      echo "Enabled Data Services: ${HOL_ENABLE_DATA_SERVICES:-n/a}"
      if workshop_services_include cdw; then
         echo "CDW Managed Identity: ${CDW_MANAGED_IDENTITY_ID:-n/a}"
      fi
      if workshop_services_include cde; then
         echo "CDE Service Name: ${workshop_name}-cde"
         echo "CDE Instance Type: ${cde_instance_type:-n/a}"
         echo "CDE Cluster Managed Identity: ${CDE_CLUSTER_MANAGED_IDENTITY_ID:-n/a}"
         echo "CDE VC Managed Identity: ${CDE_VC_MANAGED_IDENTITY_ID:-n/a}"
      fi
      if workshop_services_include cai || [[ "${provision_caii:-no}" == "yes" ]]; then
         echo "CAI Workspace Name: ${workshop_name}-cai-ws"
         echo "CAI WS Instance Type: ${cai_ws_instance_type:-n/a}"
         echo "CAI NFS Mount Path: ${CAI_EXISTING_NFS:-n/a}"
         echo "CAI NFS Storage Account: ${CAI_NFS_STORAGE_ACCOUNT:-n/a}"
         echo "CAI NFS Share: ${CAI_NFS_SHARE_NAME:-n/a}"
      fi
      if workshop_services_include cdf; then
         echo "CDF Environment Service: ${workshop_name}-cdp-env"
         echo "CDF Instance Type: ${cdf_instance_type:-n/a}"
      fi
   } >>"$out"
   hol_ok "Data service outputs appended to ${out} (also emailed via Jenkins when run from CI)"
}

#--------------------------------------------------------------------------------------------------#
# Function to configure IDP Client
cdp_idp_setup_user() {
   # echo "keycloak__admin_password:$keycloak__admin_password"
   KEYCLOAK_SERVER_IP=$(resolve_keycloak_server_ip optional || true)
   if [[ -z "$KEYCLOAK_SERVER_IP" ]]; then
      hol_fail "Cannot configure CDP IDP for '${workshop_name}': Keycloak server IP is empty after checking $(hol_keycloak_ip_path), legacy /userconfig/keycloak_ip, and Keycloak Terraform elastic_ip output. Re-provision Keycloak or restore the per-workshop IP file."
   fi
   hol_kv "Keycloak server IP" "$KEYCLOAK_SERVER_IP"
   USER_NAMESPACE=$workshop_name
   cd /userconfig/.$USER_NAMESPACE/keycloak_ansible_config
   hol_subsection "Configuring IDP in CDP" "🔗"
   wait_for_keycloak_ready "$KEYCLOAK_SERVER_IP" 30 || return 1
   cdp_region=$(cdp environments describe-environment --environment-name $workshop_name-cdp-env | jq -r .environment.crn | cut -d: -f4)
   echo "cdp_region:$cdp_region"
   ansible-playbook create_keycloak_client.yml --extra-vars \
      "keycloak__admin_username=admin \
      keycloak__admin_password=$keycloak__admin_password \
      keycloak__domain=https://$KEYCLOAK_SERVER_IP \
      keycloak__cdp_idp_name=$workshop_name \
      keycloak__realm=master \
      keycloak__auth_realm=master \
      cdp_region=$cdp_region" || hol_fail "create_keycloak_client playbook failed — Keycloak IDP client was not created"
   hol_subsection "Creating Users & Groups" "👥"
   sleep 5
   ansible-playbook keycloak_hol_user_setup.yml --extra-vars \
      "keycloak__admin_username=admin \
      keycloak__admin_password=$keycloak__admin_password \
      keycloak__domain=https://$KEYCLOAK_SERVER_IP \
      hol_keycloak_realm=master \
      hol_session_name=$workshop_name-az-cdp-user-group \
      number_user_to_create=$number_of_workshop_users \
      username_prefix=$workshop_user_prefix \
      default_user_password=$workshop_user_default_password \
      reset_password_on_first_login=True" || hol_fail "keycloak_hol_user_setup playbook failed — workshop users were not created in Keycloak"
   sleep 10
   hol_subsection "Synchronising Keycloak users in CDP" "🔄"
   for i in $(seq -f "%02g" 1 1 $number_of_workshop_users); do
      output=$(cdp iam create-user \
         --identity-provider-user-id $workshop_user_prefix$i \
         --email $workshop_user_prefix$i@clouderaexample.com \
         --saml-provider-name $workshop_name \
         --groups "$workshop_name-az-cdp-user-group" \
         --first-name User-$workshop_user_prefix$i \
         --last-name User-$workshop_user_prefix$i 2>&1)
      exit_status=$?
      if [[ $exit_status -eq 0 ]]; then
         hol_ok "CDP user '$workshop_user_prefix$i' created"
      elif echo "$output" | grep -q "ALREADY_EXISTS"; then
         hol_skip "User '$workshop_user_prefix$i' already exists"
      else
         hol_fail "cdp iam create-user failed for '$workshop_user_prefix$i': $output"
      fi
   done

   hol_cdp_sync_all_users_resilient "$workshop_name-cdp-env" || return 1
   sleep 5
   hol_subsection "Generating workshop report" "📄"
   cd /userconfig/.$USER_NAMESPACE/keycloak_ansible_config
   ansible-playbook keycloak_hol_user_fetch.yml --extra-vars \
      "keycloak__admin_username=admin \
      keycloak__admin_password=$keycloak__admin_password \
      keycloak__domain=https://$KEYCLOAK_SERVER_IP \
      hol_keycloak_realm=master \
      hol_session_name=$workshop_name-az-cdp-user-group" || hol_fail "keycloak_hol_user_fetch playbook failed"
   sleep 5
   hol_step "Fetching workshop user details for report..."
   hol_load_keycloak_report_users "$workshop_name-az-cdp-user-group"
   sleep 5
   hol_write_keycloak_workshop_report
   hol_ok "Workshop report saved to /userconfig/$workshop_name.txt"
}
#--------------------------------------------------------------------------------------------------#
cdp_idp_user_teardown() {
   USER_NAMESPACE=$workshop_name
   hol_subsection "Deleting IDP users & group" "👥"
   
   local kc_ansible_dir="/userconfig/.$USER_NAMESPACE/keycloak_ansible_config"
   KEYCLOAK_SERVER_IP=$(resolve_keycloak_server_ip optional || true)
   if [[ -n "$KEYCLOAK_SERVER_IP" && -d "$kc_ansible_dir" && -f "$kc_ansible_dir/keycloak_hol_user_teardown.yml" ]]; then
      hol_info "Keycloak server IP: $KEYCLOAK_SERVER_IP"
      cd "$kc_ansible_dir"
      ansible-playbook keycloak_hol_user_teardown.yml --extra-vars \
         "keycloak__admin_username=admin \
         keycloak__admin_password=$keycloak__admin_password \
         keycloak__domain=https://$KEYCLOAK_SERVER_IP \
         hol_keycloak_realm=master \
         hol_session_name=$workshop_name-az-cdp-user-group"
      sleep 10
   else
      hol_skip "Keycloak IDP not configured for this workshop — skipping user teardown playbook"
   fi

   hol_subsection "Removing IDP from CDP tenant" "🔗"
   if cdp iam delete-saml-provider --saml-provider-name "$workshop_name" >/dev/null 2>&1; then
      hol_ok "Removed SAML provider $workshop_name"
   else
      hol_skip "SAML provider $workshop_name not found (already removed)"
   fi
}
#--------------------------------------------------------------------------------------------------#
# Function to count elements in a JSON array variable
count_elements() {
   local var="$1"
   # Remove leading and trailing '[' and ']' characters
   local cleaned_var="${var//[[:space:]]/}" # Remove all whitespace
   cleaned_var="${cleaned_var#[}"
   cleaned_var="${cleaned_var%]}"

   # Count number of comma-separated elements
   local count=$(echo "$cleaned_var" | awk -F',' '{print NF}')
   echo "$count"
}
#--------------------------------------------------------------------------------------------------#
azure_vm_sku_available() {
   local sku="$1"
   local region="${azure_region:-}"

   [[ -n "$sku" ]] || return 1
   if [[ -z "$region" ]] || ! command -v az >/dev/null 2>&1; then
      return 0
   fi

   local count
   count=$(az vm list-skus --location "$region" --size "$sku" \
      --query "length([?name=='${sku}'])" -o tsv 2>/dev/null || echo 0)
   [[ "${count:-0}" -gt 0 ]]
}

resolve_azure_instance_type() {
   local requested="${1:-}"
   shift
   local candidates=()
   local sku existing seen

   if [[ -n "$requested" ]]; then
      candidates+=("$requested")
   fi
   while [[ $# -gt 0 ]]; do
      candidates+=("$1")
      shift
   done

   local deduped=()
   for sku in "${candidates[@]}"; do
      [[ -z "$sku" ]] && continue
      seen=0
      for existing in "${deduped[@]}"; do
         [[ "$existing" == "$sku" ]] && seen=1 && break
      done
      ((seen)) || deduped+=("$sku")
   done

   if [[ ${#deduped[@]} -eq 0 ]]; then
      return 1
   fi

   for sku in "${deduped[@]}"; do
      if azure_vm_sku_available "$sku"; then
         if [[ -n "$requested" && "$sku" != "$requested" ]]; then
            hol_warn "Requested instance type '${requested}' unavailable in ${azure_region}; using ${sku}" >&2
         else
            hol_info "Using Azure instance type ${sku}" >&2
         fi
         echo "$sku"
         return 0
      fi
      hol_warn "Azure instance type ${sku} is not offered in ${azure_region}" >&2
   done

   hol_warn "No preferred instance type verified in ${azure_region}; defaulting to ${deduped[0]}" >&2
   echo "${deduped[0]}"
}

#--------------------------------------------------------------------------------------------------#
deploy_cdw() {
   number_vw_to_create=$((($number_of_workshop_users / 10) + ($number_of_workshop_users % 10 > 0)))
   azure_cdw_subnet=$(echo "$ENV_PRIVATE_SUBNETS" | jq -r '.[0]')

   if [[ -z "${CDW_MANAGED_IDENTITY_ID:-}" && -d "/userconfig/.$workshop_name/azure_enhancements/cdw_custom_identity" ]]; then
      cd "/userconfig/.$workshop_name/azure_enhancements/cdw_custom_identity"
      CDW_MANAGED_IDENTITY_ID=$(terraform output -raw cdw_managed_identity_id 2>/dev/null || true)
      export CDW_MANAGED_IDENTITY_ID
   fi
   if [[ -z "${CDW_MANAGED_IDENTITY_ID:-}" ]]; then
      hol_fail "CDW managed identity is not set. Ensure CDW is enabled and CDP/Azure enhancements completed successfully."
   fi

   hol_run_ansible_playbook $DS_CONFIG_DIR/enable-cdw.yml --extra-vars \
      "cdp_env_name=$workshop_name-cdp-env \
      azure_subnet_name=$azure_cdw_subnet \
      workshop_name=$workshop_name \
      cdw_managed_identity_id=$CDW_MANAGED_IDENTITY_ID \
      vw_size=$cdw_vrtl_warehouse_size \
      cdvc_size=$cdw_dataviz_size \
      number_vw_to_create=$number_vw_to_create" || return $?
}
#--------------------------------------------------------------------------------------------------#
disable_cdw() {
   hol_disable_service "cdw"
   hol_run_ansible_playbook $DS_CONFIG_DIR/disable-cdw.yml --extra-vars \
      "cdp_env_name=$workshop_name-cdp-env"
}
#--------------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------------#
hol_datalake_requires_spark354() {
   local dl="${1:-}"
   if [[ -z "$dl" || "$dl" == "latest" ]]; then
      return 0
   fi
   if [[ ! "$dl" =~ ^[0-9]+\.[0-9]+ ]]; then
      return 0
   fi
   local major minor _rest
   IFS=. read -r major minor _rest <<< "$dl"
   if (( major > 7 )) || (( major == 7 && minor >= 3 )); then
      return 0
   fi
   return 1
}

hol_resolve_cde_spark_version() {
   local req="${1:-AUTO}"
   local dl="${2:-}"
   req="${req^^}"
   case "$req" in
   AUTO | '' | SPARK3)
      req="SPARK3_5"
      ;;
   esac
   if [[ "$req" == "SPARK3_5" ]] && hol_datalake_requires_spark354 "$dl"; then
      req="SPARK3_5_4"
   fi
   echo "$req"
}

deploy_cde() {
   number_vc_to_create=$((($number_of_workshop_users / 10) + ($number_of_workshop_users % 10 > 0)))
   DEFAULT_CDE_INSTANCE_TYPE="Standard_D8s_v5"
   DEFAULT_CDE_MIN_INSTANCES=0
   DEFAULT_CDE_MAX_INSTANCES=25
   if [ -z "${CDE_INSTANCE_TYPE+x}" ] || [ -z "$CDE_INSTANCE_TYPE" ]; then
      cde_instance_type=$DEFAULT_CDE_INSTANCE_TYPE
   else
      cde_instance_type=$CDE_INSTANCE_TYPE
   fi
   DEFAULT_CDE_INITIAL_INSTANCES=1
   cde_initial_instances="${cde_initial_instances:-$DEFAULT_CDE_INITIAL_INSTANCES}"
   cde_min_instances="${cde_min_instances:-$DEFAULT_CDE_MIN_INSTANCES}"
   cde_max_instances="${cde_max_instances:-$DEFAULT_CDE_MAX_INSTANCES}"
   cde_instance_type=$(resolve_azure_instance_type "$cde_instance_type" \
      Standard_D8s_v5 Standard_D8as_v5 Standard_D8ds_v5 Standard_D16s_v5)

   if [[ -z "${CDE_CLUSTER_MANAGED_IDENTITY_ID:-}" && -d "/userconfig/.$workshop_name/azure_enhancements/cde_custom_identity" ]]; then
      cd "/userconfig/.$workshop_name/azure_enhancements/cde_custom_identity"
      CDE_CLUSTER_MANAGED_IDENTITY_ID=$(terraform output -raw cde_cluster_managed_identity_id 2>/dev/null || true)
      CDE_VC_MANAGED_IDENTITY_ID=$(terraform output -raw cde_vc_managed_identity_id 2>/dev/null || true)
      export CDE_CLUSTER_MANAGED_IDENTITY_ID CDE_VC_MANAGED_IDENTITY_ID
   fi
   if [[ -z "${CDE_CLUSTER_MANAGED_IDENTITY_ID:-}" || -z "${CDE_VC_MANAGED_IDENTITY_ID:-}" ]]; then
      hol_fail "CDE managed identities are not set. Ensure CDE is enabled and CDP/Azure enhancements completed successfully."
   fi

   local cde_spark_requested="${cde_spark_version:-AUTO}"
   local cde_spark_resolved
   cde_spark_resolved="$(hol_resolve_cde_spark_version "$cde_spark_requested" "${datalake_version:-}")"
   cde_vc_tier="${cde_vc_tier:-CORE}"

   hol_run_ansible_playbook $DS_CONFIG_DIR/enable-cde.yml --extra-vars \
      "cdp_env_name=$workshop_name-cdp-env \
      workshop_name=$workshop_name \
      instance_type=$cde_instance_type \
      initial_instances=$cde_initial_instances \
      minimum_instances=$cde_min_instances \
      maximum_instances=$cde_max_instances \
      spark_version_requested=$cde_spark_requested \
      spark_version=$cde_spark_resolved \
      datalake_version=${datalake_version:-} \
      vc_tier=$cde_vc_tier \
      number_vc_to_create=$number_vc_to_create \
      cde_cluster_managed_identity_id=$CDE_CLUSTER_MANAGED_IDENTITY_ID \
      cde_vc_managed_identity_id=$CDE_VC_MANAGED_IDENTITY_ID" || return $?

}
#--------------------------------------------------------------------------------------------------#
disable_cde() {
   hol_disable_service "cde"
   hol_run_ansible_playbook $DS_CONFIG_DIR/disable-cde.yml --extra-vars \
      "workshop_name=$workshop_name"
}
#--------------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------------#
deploy_cai() {
   if should_provision_cai_nfs; then
      if [[ -z "${CAI_EXISTING_NFS:-}" ]]; then
         load_cai_nfs_from_terraform || true
      fi
      if [[ -z "${CAI_EXISTING_NFS:-}" ]]; then
         hol_fail "CAI requires Azure NFS but mount path is not set. Re-run CDP provision with CAI enabled."
      fi
      finalize_cai_nfs_mount_path
      prepare_cai_nfs_workbench_mount || return 1
   fi

   hol_run_ansible_playbook $DS_CONFIG_DIR/enable-cai.yml --extra-vars \
      "cdp_env_name=$workshop_name-cdp-env \
      workshop_name=$workshop_name \
      ws_instance_type=$cai_ws_instance_type \
      minimum_instances=$cai_min_instances \
      maximum_instances=$cai_max_instances \
      root_volume_size=256 \
      enable_gpu=$cai_enable_gpu \
      gpu_instance_type=$cai_gpu_instance_type \
      minimum_gpu_instances=$cai_min_gpu_instances \
      maximum_gpu_instances=$cai_max_gpu_instances \
      cai_existing_nfs=${CAI_EXISTING_NFS:-} \
      cai_nfs_version=${cai_nfs_version:-4.1}" || return $?
}
#--------------------------------------------------------------------------------------------------#
disable_cai() {
   hol_disable_service "cai"
   hol_run_ansible_playbook $DS_CONFIG_DIR/disable-cai.yml --extra-vars \
      "cdp_env_name=$workshop_name-cdp-env \
      workshop_name=$workshop_name"
}
#--------------------------------------------------------------------------------------------------#
deploy_cdf() {
   if [[ -z "${ENV_PUBLIC_SUBNETS:-}" || -z "${ENV_PRIVATE_SUBNETS:-}" ]]; then
      load_cdp_subnet_outputs_from_terraform || true
   fi
   if [[ -z "${ENV_PUBLIC_SUBNETS:-}" || -z "${ENV_PRIVATE_SUBNETS:-}" ]]; then
      hol_fail "CDF requires public and private subnet outputs from CDP Terraform. Re-run CDP provision or ensure azure_cdp_gateway_subnet_names and azure_cdp_subnet_names exist."
   fi

   local extra_vars_file="/tmp/cdf_extra_vars_${workshop_name}.json"

   if [[ -n "${cdf_instance_type}" ]]; then
      jq -n \
         --arg cdp_env_name "${workshop_name}-cdp-env" \
         --arg workshop_name "$workshop_name" \
         --arg instance_type "${cdf_instance_type}" \
         --argjson minimum_nodes "${cdf_min_nodes}" \
         --argjson maximum_nodes "${cdf_max_nodes}" \
         --arg use_public_load_balancer "${cdf_use_public_lb}" \
         --argjson env_lb_public_subnet "${ENV_PUBLIC_SUBNETS}" \
         --argjson env_wrkr_private_subnet "${ENV_PRIVATE_SUBNETS}" \
         '{
           cdp_env_name: $cdp_env_name,
           workshop_name: $workshop_name,
           instance_type: $instance_type,
           minimum_nodes: $minimum_nodes,
           maximum_nodes: $maximum_nodes,
           use_public_load_balancer: ($use_public_load_balancer == "true" or $use_public_load_balancer == "yes"),
           env_lb_public_subnet: $env_lb_public_subnet,
           env_wrkr_private_subnet: $env_wrkr_private_subnet
         }' > "$extra_vars_file"
   else
      jq -n \
         --arg cdp_env_name "${workshop_name}-cdp-env" \
         --arg workshop_name "$workshop_name" \
         --argjson minimum_nodes "${cdf_min_nodes}" \
         --argjson maximum_nodes "${cdf_max_nodes}" \
         --arg use_public_load_balancer "${cdf_use_public_lb}" \
         --argjson env_lb_public_subnet "${ENV_PUBLIC_SUBNETS}" \
         --argjson env_wrkr_private_subnet "${ENV_PRIVATE_SUBNETS}" \
         '{
           cdp_env_name: $cdp_env_name,
           workshop_name: $workshop_name,
           minimum_nodes: $minimum_nodes,
           maximum_nodes: $maximum_nodes,
           use_public_load_balancer: ($use_public_load_balancer == "true" or $use_public_load_balancer == "yes"),
           env_lb_public_subnet: $env_lb_public_subnet,
           env_wrkr_private_subnet: $env_wrkr_private_subnet
         }' > "$extra_vars_file"
   fi

   hol_run_ansible_playbook "$DS_CONFIG_DIR/enable-cdf.yml" -e "@${extra_vars_file}" || return $?
}
#--------------------------------------------------------------------------------------------------#
disable_cdf() {
   hol_disable_service "cdf"
   hol_run_ansible_playbook $DS_CONFIG_DIR/disable-cdf.yml --extra-vars \
      "cdp_env_name=$workshop_name-cdp-env \
      workshop_name=$workshop_name"
}
#--------------------------------------------------------------------------------------------------#

#---------------------------Start of functions for required roles to access data services-----------------------#
hol_assign_pipeline_cdp_env_admin_roles() {
   hol_subsection "Assigning CDP env admin roles (psejenkins, CDP caller, BUILD_USER_ID)" "🔐"
   local env_name="${workshop_name}-cdp-env"
   local script="" candidate
   local candidates=(
      "/usr/local/bin/assignCdpEnvAdminRoles.sh"
      "/repo/OnCloud/Azure/build/jenkins/assignCdpEnvAdminRoles.sh"
      "/repo/OnCloud/AWS/build/jenkins/assignCdpEnvAdminRoles.sh"
   )

   for candidate in "${candidates[@]}"; do
      if [[ -f "$candidate" ]]; then
         script="$candidate"
         break
      fi
   done

   if [[ -z "$script" ]]; then
      hol_fail "assignCdpEnvAdminRoles.sh not found — cannot grant DFAdmin before data services"
   fi

   chmod +x "$script"
   if ! CDP_ENV_NAME="$env_name" \
      WORKSHOP_NAME="$workshop_name" \
      BUILD_USER_ID="${BUILD_USER_ID:-}" \
      CDP_MACHINE_USERNAME="${CDP_MACHINE_USERNAME:-psejenkins}" \
      ASSIGN_BUILD_USER=true \
      ASSIGN_MACHINE_USER=true \
      ASSIGN_CALLER=true \
      "$script"; then
      hol_fail "CDP env admin role assignment failed for '${env_name}' (DFAdmin required for CDF enable)"
   fi
   hol_ok "Env admin roles assigned on ${env_name} (psejenkins, CDP ~/.cdp caller, BUILD_USER_ID when set)"
}

assign_environment_base_roles() {
   hol_subsection "Assigning EnvironmentUser resource role" "🔐"
   local resource_roles=("EnvironmentUser")
   set_resource_roles $workshop_name-az-cdp-user-group $workshop_name-cdp-env "${resource_roles[@]}"
}

set_account_roles() {
   CDP_GROUP_NAME=${1}
   shift
   ACCOUNT_ROLES=("$@")

   # Get Account Role CRN
   get_crn_account_role() {
      CDP_ACCOUNT_ROLE_NAME=$1
      CDP_ACCOUNT_ROLE_CRN=$(cdp iam list-roles | jq --arg CDP_ACCOUNT_ROLE_NAME "$CDP_ACCOUNT_ROLE_NAME" '.roles[] | select(.crn | endswith($CDP_ACCOUNT_ROLE_NAME)) | .crn')
      echo $CDP_ACCOUNT_ROLE_CRN | tr -d '"'
   }

   # Assign Account Roles with error handling
   for role_name in "${ACCOUNT_ROLES[@]}"; do
      # Assign the account role and capture output
      output=$(cdp iam assign-group-role --group-name ${CDP_GROUP_NAME} --role $(get_crn_account_role ${role_name}) 2>&1)

      # Check the exit status of the previous command
      exit_status=$?

      if [ $exit_status -eq 0 ]; then
         hol_role_ok "$role_name" "$CDP_GROUP_NAME"
      elif echo "$output" | grep -q "ALREADY_EXISTS"; then
         hol_role_skip "$role_name" "$CDP_GROUP_NAME"
      else
         hol_role_error "$role_name" "$CDP_GROUP_NAME"
         echo "$output"
      fi
   done

   # Verify assigned roles
   cdp iam list-group-assigned-roles --group-name ${CDP_GROUP_NAME}
}

set_resource_roles() {
   CDP_GROUP_NAME=${1}
   CDP_ENV_NAME=${2}
   shift 2
   RESOURCE_ROLES=("$@")

   # Get Group CRN
   export CDP_GROUP_CRN=$(cdp iam list-groups | jq --arg CDP_GROUP_NAME "$CDP_GROUP_NAME" '.groups[] | select(.groupName == $CDP_GROUP_NAME).crn')
   # Get Environment CRN
   export CDP_ENV_CRN=$(cdp environments describe-environment --environment-name ${CDP_ENV_NAME} | jq -r .environment.crn)

   # Function: Get Resource Roles CRN
   get_crn_resource_role() {
      CDP_RESOURCE_ROLE_NAME=$1
      CDP_RESOURCE_ROLE_CRN=$(cdp iam list-resource-roles | jq --arg CDP_RESOURCE_ROLE_NAME "$CDP_RESOURCE_ROLE_NAME" '.resourceRoles[] | select(.crn | endswith($CDP_RESOURCE_ROLE_NAME)) | .crn')
      echo $CDP_RESOURCE_ROLE_CRN | tr -d '"'
   }

   # Set Resource Roles with error handling
   for role_name in "${RESOURCE_ROLES[@]}"; do
      # Assign the resource role and capture output
      output=$(cdp iam assign-group-resource-role --group-name $CDP_GROUP_NAME --resource-role-crn $(get_crn_resource_role ${role_name}) --resource-crn $CDP_ENV_CRN 2>&1)

      # Check the exit status of the previous command
      exit_status=$?

      if [ $exit_status -eq 0 ]; then
         hol_role_ok "$role_name" "$CDP_GROUP_NAME"
      elif echo "$output" | grep -q "ALREADY_EXISTS"; then
         hol_role_skip "$role_name" "$CDP_GROUP_NAME"
      else
         hol_role_error "$role_name" "$CDP_GROUP_NAME"
         echo "$output"
      fi
   done

   # Verify assigned resource-roles
   cdp iam list-group-assigned-resource-roles --group-name $CDP_GROUP_NAME
}
#-----------------------------------End of functions for required roles to access data services-----------------------------#

wait_for_pids() {
   local failed=0
   local pid
   for pid in "$@"; do
      if ! wait "$pid"; then
         failed=1
      fi
   done
   return $failed
}

deploy_single_data_service() {
   local service="$1"
   local status=0

   export HOL_SERVICE_TAG="$(hol_service_short "$service")"

   case "$service" in
   cdw)
      hol_init_service "cdw"
      DEFAULT_CDW_VRTL_WAREHOUSE_SIZE="xsmall"
      DEFAULT_CDW_DATAVIZ_SIZE="viz-default"
      cdw_vrtl_warehouse_size="${cdw_vrtl_warehouse_size:-$DEFAULT_CDW_VRTL_WAREHOUSE_SIZE}"
      cdw_dataviz_size="${cdw_dataviz_size:-$DEFAULT_CDW_DATAVIZ_SIZE}"
      hol_service_vars \
         "Virtual Warehouse Size" "$cdw_vrtl_warehouse_size" \
         "DataViz Size" "$cdw_dataviz_size"
      hol_deploy_service "cdw"
      deploy_cdw || status=1
      if [[ $status -eq 0 ]]; then
         resource_roles=("DWAdmin" "DWUser")
         set_resource_roles $workshop_name-az-cdp-user-group $workshop_name-cdp-env "${resource_roles[@]}"
      fi
      ;;
   cde)
      hol_init_service "cde"
      DEFAULT_CDE_INSTANCE_TYPE="Standard_D8s_v5"
      DEFAULT_CDE_MIN_INSTANCES=0
      DEFAULT_CDE_MAX_INSTANCES=25
      DEFAULT_CDE_SPARK_VERSION="AUTO"
      DEFAULT_CDE_VC_TIER="CORE"
      cde_instance_type="${cde_instance_type:-$DEFAULT_CDE_INSTANCE_TYPE}"
      cde_instance_type=$(resolve_azure_instance_type "$cde_instance_type" \
         Standard_D8s_v5 Standard_D8as_v5 Standard_D8ds_v5 Standard_D16s_v5)
      DEFAULT_CDE_INITIAL_INSTANCES=1
      cde_initial_instances="${cde_initial_instances:-$DEFAULT_CDE_INITIAL_INSTANCES}"
      cde_min_instances="${cde_min_instances:-$DEFAULT_CDE_MIN_INSTANCES}"
      cde_max_instances="${cde_max_instances:-$DEFAULT_CDE_MAX_INSTANCES}"
      cde_spark_version="${cde_spark_version:-$DEFAULT_CDE_SPARK_VERSION}"
      cde_spark_version_resolved="$(hol_resolve_cde_spark_version "$cde_spark_version" "${datalake_version:-}")"
      cde_vc_tier="${cde_vc_tier:-$DEFAULT_CDE_VC_TIER}"
      hol_service_vars \
         "Instance Type" "$cde_instance_type" \
         "Initial Instances" "$cde_initial_instances" \
         "Min Instances" "$cde_min_instances" \
         "Max Instances" "$cde_max_instances" \
         "Spark Version" "$cde_spark_version_resolved" \
         "Virtual Cluster Tier" "$cde_vc_tier"
      hol_deploy_service "cde"
      deploy_cde || status=1
      if [[ $status -eq 0 ]]; then
         resource_roles=("DEUser")
         set_resource_roles $workshop_name-az-cdp-user-group $workshop_name-cdp-env "${resource_roles[@]}"
      fi
      ;;
   cai)
      hol_init_service "cai"
      DEFAULT_CAI_WS_INSTANCE_TYPE="Standard_D8s_v5"
      DEFAULT_CAI_MIN_INSTANCES=1
      DEFAULT_CAI_MAX_INSTANCES=10
      DEFAULT_CAI_ENABLE_GPU="false"
      DEFAULT_CAI_GPU_INSTANCE_TYPE="Standard_NC4as_T4_v3"
      DEFAULT_CAI_MIN_GPU_INSTANCES=0
      DEFAULT_CAI_MAX_GPU_INSTANCES=10
      cai_ws_instance_type="${cai_ws_instance_type:-$DEFAULT_CAI_WS_INSTANCE_TYPE}"
      cai_ws_instance_type=$(resolve_azure_instance_type "$cai_ws_instance_type" \
         Standard_D8s_v5 Standard_D8as_v5 Standard_D8ds_v5 Standard_D16s_v5)
      cai_min_instances="${cai_min_instances:-$DEFAULT_CAI_MIN_INSTANCES}"
      cai_max_instances="${cai_max_instances:-$DEFAULT_CAI_MAX_INSTANCES}"
      cai_enable_gpu="${cai_enable_gpu:-$DEFAULT_CAI_ENABLE_GPU}"
      cai_gpu_instance_type="${cai_gpu_instance_type:-$DEFAULT_CAI_GPU_INSTANCE_TYPE}"
      cai_min_gpu_instances="${cai_min_gpu_instances:-$DEFAULT_CAI_MIN_GPU_INSTANCES}"
      cai_max_gpu_instances="${cai_max_gpu_instances:-$DEFAULT_CAI_MAX_GPU_INSTANCES}"
      hol_service_vars \
         "WS Instance Type" "$cai_ws_instance_type" \
         "Min Instances" "$cai_min_instances" \
         "Max Instances" "$cai_max_instances" \
         "Enable GPU" "$cai_enable_gpu" \
         "GPU Instance Type" "$cai_gpu_instance_type" \
         "Min GPU Instances" "$cai_min_gpu_instances" \
         "Max GPU Instances" "$cai_max_gpu_instances"
      hol_deploy_service "cai"
      deploy_cai || status=1
      if [[ $status -eq 0 ]]; then
         resource_roles=("MLUser")
         set_resource_roles $workshop_name-az-cdp-user-group $workshop_name-cdp-env "${resource_roles[@]}"
      fi
      ;;
   cdf)
      hol_init_service "cdf"
      DEFAULT_CDF_INSTANCE_TYPE=""
      DEFAULT_CDF_MIN_NODES=3
      DEFAULT_CDF_MAX_NODES=10
      DEFAULT_CDF_USE_PUBLIC_LB="true"
      cdf_instance_type="${cdf_instance_type:-$DEFAULT_CDF_INSTANCE_TYPE}"
      if [[ -n "${cdf_instance_type}" ]]; then
         cdf_instance_type=$(resolve_azure_instance_type "$cdf_instance_type" \
            Standard_D8s_v5 Standard_D8as_v5 Standard_D8ds_v5 Standard_D16s_v5)
      fi
      cdf_min_nodes="${cdf_min_nodes:-$DEFAULT_CDF_MIN_NODES}"
      cdf_max_nodes="${cdf_max_nodes:-$DEFAULT_CDF_MAX_NODES}"
      cdf_use_public_lb="${cdf_use_public_lb:-$DEFAULT_CDF_USE_PUBLIC_LB}"
      hol_service_vars \
         "Instance Type" "${cdf_instance_type:-CDP default}" \
         "Min Nodes" "$cdf_min_nodes" \
         "Max Nodes" "$cdf_max_nodes" \
         "Use Public Load Balancer" "$cdf_use_public_lb"
      hol_deploy_service "cdf"
      deploy_cdf || status=1
      if [[ $status -eq 0 ]]; then
         resource_roles=("DFFlowUser" "DFFlowDeveloper")
         set_resource_roles $workshop_name-az-cdp-user-group $workshop_name-cdp-env "${resource_roles[@]}"
      fi
      ;;
   *)
      hol_warn "Unknown data service: $service"
      status=1
      ;;
   esac

   unset HOL_SERVICE_TAG
   return $status
}

disable_single_data_service() {
   local service="$1"
   local status=0

   export HOL_SERVICE_TAG="$(hol_service_short "$service")"

   case "$service" in
   cdw) disable_cdw || status=1 ;;
   cde) disable_cde || status=1 ;;
   cai) disable_cai || status=1 ;;
   cdf) disable_cdf || status=1 ;;
   *)
      hol_warn "Unknown data service: $service"
      status=1
      ;;
   esac

   unset HOL_SERVICE_TAG
   return $status
}

hol_enable_data_services() {
   hol_fixup_cloudera_cloud_python

   local selected_services csv
   selected_services=$(hol_enabled_data_services_csv)

   IFS=',' read -ra data_services <<<"$selected_services"
   local services_to_deploy=()
   local service token

   hol_info "ENABLE_DATA_SERVICES config: ${HOL_ENABLE_DATA_SERVICES:-n/a}"

   for service in "${data_services[@]}"; do
      token=$(hol_normalize_data_service_token "$service")
      [[ -z "$token" ]] && continue
      if [[ "$token" == "cai" && "$provision_caii" == "yes" ]]; then
         hol_skip "CAI skipped in data services list — provisioned by CAII"
         continue
      fi
      services_to_deploy+=("$token")
   done

   if [ "${#services_to_deploy[@]}" -eq 0 ]; then
      hol_info "No data services selected"
      return 0
   fi

   hol_assign_pipeline_cdp_env_admin_roles || return 1

   local failed=0
   local pids=()
   local delay=0
   local service

   hol_stop_service_log_tailers
   for service in "${services_to_deploy[@]}"; do
      hol_start_service_log_tailer "$(hol_service_short "$service")"
   done

   hol_parallel_start
   hol_info "Services: ${services_to_deploy[*]} (live logs: /userconfig/.${workshop_name}/logs/)"

   for service in "${services_to_deploy[@]}"; do
      (
         if (( delay > 0 )); then
            sleep "$delay"
         fi
         deploy_single_data_service "$service"
      ) &
      pids+=($!)
      delay=$((delay + 25))
   done

   wait_for_pids "${pids[@]}" || failed=1
   hol_stop_service_log_tailers
   if (( failed != 0 )); then
      hol_warn "One or more data service playbooks failed — see /userconfig/.${workshop_name}/logs/*.log"
   fi
   return $failed
}
#--------------------------------------------------------------------------------------------------#
disable_data_services() {
   local selected_services token
   selected_services=$(hol_enabled_data_services_csv)

   IFS=',' read -ra data_services <<<"$selected_services"
   local services_to_disable=()
   local service

   for service in "${data_services[@]}"; do
      token=$(hol_normalize_data_service_token "$service")
      [[ -z "$token" ]] && continue
      services_to_disable+=("$token")
   done

   if [ "${#services_to_disable[@]}" -eq 0 ]; then
      hol_info "No data services to disable"
      return 0
   fi

   hol_subsection "Disabling data services in parallel" "🗑️"
   hol_info "Services: ${services_to_disable[*]}"

   local pids=()
   local service

   hol_stop_service_log_tailers
   for service in "${services_to_disable[@]}"; do
      hol_start_service_log_tailer "$(hol_service_short "$service")"
   done

   for service in "${services_to_disable[@]}"; do
      disable_single_data_service "$service" &
      pids+=($!)
   done

   wait_for_pids "${pids[@]}"
   hol_stop_service_log_tailers

   hol_subsection "Disable playbook logs" "📋"
   for service in "${services_to_disable[@]}"; do
      hol_kv "$(hol_service_short "$service")" "/userconfig/.${workshop_name}/logs/$(hol_service_short "$service").log"
   done
}
#--------------------------------------------------------------------------------------------------#
