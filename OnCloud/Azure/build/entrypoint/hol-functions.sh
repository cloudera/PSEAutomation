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

#TF_QUICKSTART_VERSION=v0.8.0
USER_CONFIG_FILE="/userconfig/configfile"
KEYGEN_TF_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/keypair_gen
KC_TF_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/cdp-kc-config/keycloak_terraform_config
KC_ANS_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/cdp-kc-config/keycloak_ansible_config
DS_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/cdp-data-services
ENHANCEMENTS_TF_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/azure_enhancements/
CAII_SCRIPTS_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/CAII
USER_ACTION=$1
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
         # AWS_ACCESS_KEY_ID)
         #    aws_access_key_id=$value
         #    ;;
         # AWS_SECRET_ACCESS_KEY)
         #    aws_secret_access_key=$value
         #    ;;
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
            enable_data_services=$value
            ;;
         CDW_VRTL_WAREHOUSE_SIZE)
            cdw_vrtl_warehouse_size=$(echo $value | tr '[:upper:]' '[:lower:]')
            ;;
         CDW_DATAVIZ_SIZE)
            cdw_dataviz_size=$(echo $value | tr '[:upper:]' '[:lower:]')
            ;;
         CDE_INSTANCE_TYPE)
            cde_instance_type=$(echo $value | tr '[:upper:]' '[:lower:]')
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
            cai_ws_instance_type=$(echo $value | tr '[:upper:]' '[:lower:]')
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
            cai_gpu_instance_type=$(echo $value | tr '[:upper:]' '[:lower:]')
            ;;
         CAI_MIN_GPU_INSTANCES)
            cai_min_gpu_instances=$value
            ;;
         CAI_MAX_GPU_INSTANCES)
            cai_max_gpu_instances=$value
            ;;
         CDF_INSTANCE_TYPE)
            cdf_instance_type=$(echo $value | tr '[:upper:]' '[:lower:]')
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
   hol_fail "Azure CLI is not authenticated. Jenkins: -v /home/holautosa/.azure:/root/.azure  Local: -v \$HOME/.azure:/root/.azure"
}

ensure_aws_cli_for_dns() {
   [[ "$provision_keycloak" != "yes" ]] && return 0
   if aws sts get-caller-identity --query Account --output text &>/dev/null; then
      return 0
   fi
   hol_fail "AWS CLI required for Keycloak DNS. Jenkins: -v /home/holautosa/.aws:/root/.aws  Local: -v \$HOME/.aws:/root/.aws"
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

get_cdp_network_for_keycloak() {
   local azure_tf_dir="/userconfig/.$USER_NAMESPACE/cdp-tf-quickstarts/azure"
   if [[ ! -d "${azure_tf_dir}" ]]; then
      hol_fail "CDP Terraform directory not found at ${azure_tf_dir}. Provision CDP before Keycloak."
   fi
   cd "${azure_tf_dir}" || hol_fail "Unable to enter CDP Terraform directory: ${azure_tf_dir}"
   KC_RESOURCE_GROUP=$(terraform output -raw azure_resource_group_name)
   KC_NETWORK_RG=$(terraform output -raw azure_network_resource_group_name 2>/dev/null || terraform output -raw azure_resource_group_name)
   KC_VNET_NAME=$(terraform output -raw azure_vnet_name)
   KC_SUBNET_NAME=$(terraform output -json azure_cdp_gateway_subnet_names | jq -r '.[0]')
   if [[ -z "$KC_RESOURCE_GROUP" || -z "$KC_NETWORK_RG" || -z "$KC_VNET_NAME" || -z "$KC_SUBNET_NAME" || "$KC_SUBNET_NAME" == "null" ]]; then
      hol_fail "Unable to read CDP network outputs required for Keycloak (resource group, VNet, or gateway subnet)."
   fi
   hol_kv "Keycloak resource group" "$KC_RESOURCE_GROUP"
   hol_kv "Keycloak network resource group" "$KC_NETWORK_RG"
   hol_kv "Keycloak VNet" "$KC_VNET_NAME"
   hol_kv "Keycloak gateway subnet" "$KC_SUBNET_NAME"
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
   # Run Terraform to provision Keycloak instance
   if check_azure_nsg_exists "$sg_name"; then
      hol_warn "Security group '$sg_name' exists — using '$sg_name-$workshop_name-sg'"
      sg_name="$sg_name-$workshop_name"
   fi

   terraform init
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
   if [ $RETURN -eq 0 ]; then
      KEYCLOAK_SERVER_IP=$(terraform output -raw elastic_ip)
      hol_step "Saving Keycloak IP to /userconfig/keycloak_ip"
      echo "$KEYCLOAK_SERVER_IP" >/userconfig/keycloak_ip
      hol_ok "Keycloak instance IP: $KEYCLOAK_SERVER_IP"
   else
      return 1
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
   hol_subsection "Destroying Keycloak" "🔐"
   local sg_name="${workshop_name}-keyc-sg"
   if check_azure_nsg_exists "$sg_name"; then
      sg_name="${sg_name}-${workshop_name}"
   fi
   get_cdp_network_for_keycloak
   cd /userconfig/.$USER_NAMESPACE/keycloak_terraform_config
   terraform init
   hol_step "Waiting 30 seconds before Keycloak teardown..."
   sleep 30
   hol_step "Deleting Route53 DNS record"
   # Delete Route53 DNS record to unmap subdomain to instance IP
   aws route53 change-resource-record-sets --hosted-zone-id "$hostedzoneid" \
      --change-batch '{
        "Changes": [{
            "Action": "DELETE",
            "ResourceRecordSet": {
                "Name": "'"$workshop_name.$domain"'",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [{"Value": "'"$(terraform output -raw elastic_ip)"'"}]
            }
        }]
    }'
   hol_ok "DNS record deleted for $workshop_name.$domain"

   # Extract only the first IP for Keycloak (admin access only)
   kc_ip=$(echo "$local_ip" | cut -d',' -f1)
   terraform destroy -auto-approve \
      -var "workshop_name=$workshop_name" \
      -var "local_ip=$kc_ip" \
      -var "ssh_key_name=$ssh_key_name" \
      -var "ssh_public_key=${ssh_public_key:-placeholder}" \
      -var "azure_region=$azure_region" \
      -var "domain=${domain:-example.com}" \
      -var "wildcard_fullchain=placeholder" \
      -var "wildcard_privkey=placeholder" \
      -var "kc_security_group=$sg_name" \
      -var "keycloak_admin_password=$keycloak__admin_password" \
      -var "resource_group_name=$KC_RESOURCE_GROUP" \
      -var "network_resource_group_name=$KC_NETWORK_RG" \
      -var "vnet_name=$KC_VNET_NAME" \
      -var "subnet_name=$KC_SUBNET_NAME"
   RETURN=$?
   if [ $RETURN -eq 0 ]; then
      rm -rf /userconfig/.$USER_NAMESPACE/keycloak_terraform_config
      rm -rf /userconfig/.$USER_NAMESPACE/keycloak_ansible_config
      rm -rf /userconfig/keycloak_ip
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
   local selected_services="${enable_data_services//[/}"
   selected_services="${selected_services//]/}"
   selected_services=$(echo "$selected_services" | tr '[:upper:]' '[:lower:]')
   [[ ",${selected_services}," == *",cdw,"* ]]
}

# Return 0 when CAI or CAII is selected and Azure NFS should be provisioned.
should_provision_cai_nfs() {
   [[ "${provision_caii:-no}" == "yes" ]] && return 0
   local selected_services="${enable_data_services//[/}"
   selected_services="${selected_services//]/}"
   selected_services=$(echo "$selected_services" | tr '[:upper:]' '[:lower:]')
   [[ ",${selected_services}," == *",cai,"* ]]
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
EOF
   fi
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
      hol_info "NFS is provisioned with CDP infra (same RG/VNet) — premium FileStorage, private endpoints, secure transfer disabled"
      patch_cdp_quickstart_for_cai_nfs "${azure_tf_dir}"
   fi
   terraform init

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

   hol_subsection "Running Terraform for CDP environment & datalake" "☁️"
   terraform apply --auto-approve "${cdp_tf_apply_args[@]}"

   if [ $? -ne 0 ]; then
      return 1
   fi

   assign_environment_base_roles

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
      export AZURE_RESOURCE_GROUP=$(terraform output -raw azure_resource_group_name)

      if should_provision_cai_nfs; then
         NFS_FILE_SHARE_URL=$(terraform output -raw nfs_file_share_url 2>/dev/null || true)
         NFS_STORAGE_ACCOUNT=$(terraform output -raw nfs_storage_account_name 2>/dev/null || true)
         if [[ -n "$NFS_FILE_SHARE_URL" ]]; then
            hol_kv "CAI NFS share URL" "$NFS_FILE_SHARE_URL"
            hol_kv "CAI NFS storage account" "$NFS_STORAGE_ACCOUNT"
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

      azure_enhancements #calling azure_enhancements function
      azure_enhancements_status=$?
      if [ $azure_enhancements_status -ne 0 ]; then
         hol_warn "Azure enhancements failed to apply — check logs for details"
      fi
      if [[ -n "${CDW_MANAGED_IDENTITY_ID:-}" ]]; then
         export CDW_MANAGED_IDENTITY_ID
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

   if [ ! -d "/userconfig/.$USER_NAMESPACE/$ENHANCEMENTS_TF_CONFIG_DIR" ]; then
      cp -R "$ENHANCEMENTS_TF_CONFIG_DIR" "/userconfig/.$USER_NAMESPACE/"
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

   if should_provision_cdw; then
      hol_subsection "Provisioning CDW custom identity and role" "🏢"
      cd /userconfig/.$USER_NAMESPACE/azure_enhancements/cdw_custom_identity
      terraform init
      terraform apply -auto-approve \
         -var="env_prefix=$workshop_name" \
         -var="resource_group_name=$AZURE_RESOURCE_GROUP" \
         -var="azure_region=$azure_region"
      export CDW_MANAGED_IDENTITY_ID=$(terraform output -raw cdw_managed_identity_id)
      hol_kv "CDW managed identity" "$CDW_MANAGED_IDENTITY_ID"
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
   fi
   local cdp_tf_destroy_args=(
      -var "env_prefix=${workshop_name}"
      -var "azure_region=${azure_region}"
      -var "public_key_text=${ssh_public_key:-placeholder}"
      -var "deployment_template=${deployment_template}"
      -var "ingress_extra_cidrs_and_ports={cidrs = [${cdp_cidr}],ports = [443, 22]}"
   )
   append_cdp_nfs_tf_args cdp_tf_destroy_args
   terraform destroy --auto-approve "${cdp_tf_destroy_args[@]}"
      
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
# Function to configure IDP Client
cdp_idp_setup_user() {
   # echo "keycloak__admin_password:$keycloak__admin_password"
   KEYCLOAK_SERVER_IP=$(cat /userconfig/keycloak_ip)
   USER_NAMESPACE=$workshop_name
   cd /userconfig/.$USER_NAMESPACE/keycloak_ansible_config
   hol_subsection "Configuring IDP in CDP" "🔗"
   sleep 5
   cdp_region=$(cdp environments describe-environment --environment-name $workshop_name-cdp-env | jq -r .environment.crn | cut -d: -f4)
   echo "cdp_region:$cdp_region"
   ansible-playbook create_keycloak_client.yml --extra-vars \
      "keycloak__admin_username=admin \
      keycloak__admin_password=$keycloak__admin_password \
      keycloak__domain=https://$KEYCLOAK_SERVER_IP \
      keycloak__cdp_idp_name=$workshop_name \
      keycloak__realm=master \
      keycloak__auth_realm=master \
      cdp_region=$cdp_region"
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
      reset_password_on_first_login=True"
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
      if echo "$output" | grep -q "ALREADY_EXISTS"; then
         echo "User '$workshop_user_prefix$i' already exists. Skipping..."
      fi
   done

   cdp environments sync-all-users --environment-names $workshop_name-cdp-env
   sleep 5
   hol_subsection "Generating workshop report" "📄"
   cd /userconfig/.$USER_NAMESPACE/keycloak_ansible_config
   ansible-playbook keycloak_hol_user_fetch.yml --extra-vars \
      "keycloak__admin_username=admin \
      keycloak__admin_password=$keycloak__admin_password \
      keycloak__domain=https://$KEYCLOAK_SERVER_IP \
      hol_keycloak_realm=master \
      hol_session_name=$workshop_name-az-cdp-user-group"
   sleep 5
   hol_step "Fetching workshop user details for report..."
   sample_keycloak_user1=$(cat /tmp/$workshop_name-az-cdp-user-group.json | jq -r '.[0].username')
   sample_keycloak_user2=$(cat /tmp/$workshop_name-az-cdp-user-group.json | jq -r '.[1].username')
   sleep 5
   echo "===============================================================" >>"/userconfig/$workshop_name.txt"
   echo "            Keycloak Details For $workshop_name HOL:           " >>"/userconfig/$workshop_name.txt"
   echo "===============================================================" >>"/userconfig/$workshop_name.txt"
   echo "Keycloak Server IP: $KEYCLOAK_SERVER_IP" >>"/userconfig/$workshop_name.txt"
   echo "Keycloak Admin HTTPS URL: https://$workshop_name.$domain" >>"/userconfig/$workshop_name.txt"
   echo "Keycloak Admin User: admin" >>"/userconfig/$workshop_name.txt"
   echo "Keycloak Admin Password: $keycloak__admin_password" >>"/userconfig/$workshop_name.txt"
   echo "Keycloak SSO HTTPS URL: https://$workshop_name.$domain/realms/master/protocol/saml/clients/cdp-sso" >>"/userconfig/$workshop_name.txt"
   echo "Numbers Of Users Created: $number_of_workshop_users" >>"/userconfig/$workshop_name.txt"
   echo "Sample Usernames: User1: $sample_keycloak_user1, User2: $sample_keycloak_user2" >>"/userconfig/$workshop_name.txt"
   echo "Default Password for HOL Users: $workshop_user_default_password " >>"/userconfig/$workshop_name.txt"
   echo "UserAssignment App Admin URL: http://$KEYCLOAK_SERVER_IP:5000/admin" >>"/userconfig/$workshop_name.txt"
   echo "UserAssignment App Participant URL: http://$KEYCLOAK_SERVER_IP:5000/participant" >>"/userconfig/$workshop_name.txt"
   echo "===============================================================" >>"/userconfig/$workshop_name.txt"
   hol_ok "Workshop report saved to /userconfig/$workshop_name.txt"
}
#--------------------------------------------------------------------------------------------------#
cdp_idp_user_teardown() {
   USER_NAMESPACE=$workshop_name
   hol_subsection "Deleting IDP users & group" "👥"
   
   local kc_ansible_dir="/userconfig/.$USER_NAMESPACE/keycloak_ansible_config"
   if [[ -f /userconfig/keycloak_ip && -d "$kc_ansible_dir" && -f "$kc_ansible_dir/keycloak_hol_user_teardown.yml" ]]; then
      KEYCLOAK_SERVER_IP=$(cat /userconfig/keycloak_ip)
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

   ansible-playbook $DS_CONFIG_DIR/enable-cdw.yml --extra-vars \
      "cdp_env_name=$workshop_name-cdp-env \
      azure_subnet_name=$azure_cdw_subnet \
      workshop_name=$workshop_name \
      cdw_managed_identity_id=$CDW_MANAGED_IDENTITY_ID \
      vw_size=$cdw_vrtl_warehouse_size \
      cdvc_size=$cdw_dataviz_size \
      number_vw_to_create=$number_vw_to_create"
}
#--------------------------------------------------------------------------------------------------#
disable_cdw() {
   hol_disable_service "cdw"
   ansible-playbook $DS_CONFIG_DIR/disable-cdw.yml --extra-vars \
      "cdp_env_name=$workshop_name-cdp-env"
}
#--------------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------------#
deploy_cde() {
   number_vc_to_create=$((($number_of_workshop_users / 10) + ($number_of_workshop_users % 10 > 0)))
   DEFAULT_CDE_INSTANCE_TYPE="Standard_D8s_v3"
   if [ -z "${CDE_INSTANCE_TYPE+x}" ] || [ -z "$CDE_INSTANCE_TYPE" ]; then
      cde_instance_type=$DEFAULT_CDE_INSTANCE_TYPE
   else
      cde_instance_type=$CDE_INSTANCE_TYPE
   fi

   ansible-playbook $DS_CONFIG_DIR/enable-cde.yml --extra-vars \
      "cdp_env_name=$workshop_name-cdp-env \
      workshop_name=$workshop_name \
      instance_type=$cde_instance_type \
      initial_instances=$cde_initial_instances \
      minimum_instances=$cde_min_instances \
      maximum_instances=$cde_max_instances \
      spark_version=$cde_spark_version \
      vc_tier=$cde_vc_tier \
      number_vc_to_create=$number_vc_to_create"

}
#--------------------------------------------------------------------------------------------------#
disable_cde() {
   hol_disable_service "cde"
   ansible-playbook $DS_CONFIG_DIR/disable-cde.yml --extra-vars \
      "workshop_name=$workshop_name"
}
#--------------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------------#
deploy_cai() {
   #number_vws_to_create=$(( ($number_of_workshop_users / 10) + ($number_of_workshop_users % 10 > 0) ))
   ansible-playbook $DS_CONFIG_DIR/enable-cai.yml --extra-vars \
      "cdp_env_name=$workshop_name-cdp-env \
      workshop_name=$workshop_name \
      ws_instance_type=$cai_ws_instance_type \
      minimum_instances=$cai_min_instances \
      maximum_instances=$cai_max_instances \
      root_volume_size=256 \
      enable_gpu=$cai_enable_gpu \
      gpu_instance_type=$cai_gpu_instance_type \
      minimum_gpu_instances=$cai_min_gpu_instances \
      maximum_gpu_instances=$cai_max_gpu_instances"
   #number_vws_to_create=$number_vws_to_create"
}
#--------------------------------------------------------------------------------------------------#
disable_cai() {
   hol_disable_service "cai"
   ansible-playbook $DS_CONFIG_DIR/disable-cai.yml --extra-vars \
      "cdp_env_name=$workshop_name-cdp-env \
      workshop_name=$workshop_name"
}
#--------------------------------------------------------------------------------------------------#
deploy_cdf() {
   if [[ -z "${ENV_PUBLIC_SUBNETS}" || -z "${ENV_PRIVATE_SUBNETS}" ]]; then
      hol_warn "ENV_PUBLIC_SUBNETS/ENV_PRIVATE_SUBNETS are not set — cannot deploy CDF"
      return 1
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

   ansible-playbook "$DS_CONFIG_DIR/enable-cdf.yml" -e "@${extra_vars_file}"
}
#--------------------------------------------------------------------------------------------------#
disable_cdf() {
   hol_disable_service "cdf"
   ansible-playbook $DS_CONFIG_DIR/disable-cdf.yml --extra-vars \
      "cdp_env_name=$workshop_name-cdp-env \
      workshop_name=$workshop_name"
}
#--------------------------------------------------------------------------------------------------#

#---------------------------Start of functions for required roles to access data services-----------------------#
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
      DEFAULT_CDE_INSTANCE_TYPE="Standard_D8s_v3"
      DEFAULT_CDE_INITIAL_INSTANCES=10
      DEFAULT_CDE_MIN_INSTANCES=10
      DEFAULT_CDE_MAX_INSTANCES=40
      DEFAULT_CDE_SPARK_VERSION="AUTO"
      DEFAULT_CDE_VC_TIER="CORE"
      cde_instance_type="${cde_instance_type:-$DEFAULT_CDE_INSTANCE_TYPE}"
      cde_initial_instances="${cde_initial_instances:-$DEFAULT_CDE_INITIAL_INSTANCES}"
      cde_min_instances="${cde_min_instances:-$DEFAULT_CDE_MIN_INSTANCES}"
      cde_max_instances="${cde_max_instances:-$DEFAULT_CDE_MAX_INSTANCES}"
      cde_spark_version="${cde_spark_version:-$DEFAULT_CDE_SPARK_VERSION}"
      cde_vc_tier="${cde_vc_tier:-$DEFAULT_CDE_VC_TIER}"
      hol_service_vars \
         "Instance Type" "$cde_instance_type" \
         "Initial Instances" "$cde_initial_instances" \
         "Min Instances" "$cde_min_instances" \
         "Max Instances" "$cde_max_instances" \
         "Spark Version" "$cde_spark_version" \
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
      DEFAULT_CAI_WS_INSTANCE_TYPE="m5.2xlarge"
      DEFAULT_CAI_MIN_INSTANCES=1
      DEFAULT_CAI_MAX_INSTANCES=10
      DEFAULT_CAI_ENABLE_GPU="false"
      DEFAULT_CAI_GPU_INSTANCE_TYPE="g4dn.xlarge"
      DEFAULT_CAI_MIN_GPU_INSTANCES=0
      DEFAULT_CAI_MAX_GPU_INSTANCES=10
      cai_ws_instance_type="${cai_ws_instance_type:-$DEFAULT_CAI_WS_INSTANCE_TYPE}"
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
      cdf_min_nodes="${cdf_min_nodes:-$DEFAULT_CDF_MIN_NODES}"
      cdf_max_nodes="${cdf_max_nodes:-$DEFAULT_CDF_MAX_NODES}"
      cdf_use_public_lb="${cdf_use_public_lb:-$DEFAULT_CDF_USE_PUBLIC_LB}"
      hol_service_vars \
         "Instance Type" "$cdf_instance_type" \
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

enable_data_services() {
   local selected_services="${enable_data_services//[/}"
   selected_services="${selected_services//]/}"
   selected_services=$(echo "$selected_services" | tr '[:upper:]' '[:lower:]')

   IFS=',' read -ra data_services <<<"$selected_services"
   local services_to_deploy=()
   local service

   for service in "${data_services[@]}"; do
      service=$(echo "$service" | xargs)
      [[ -z "$service" || "$service" == "none" ]] && continue
      if [[ "$service" == "cai" && "$provision_caii" == "yes" ]]; then
         hol_skip "CAI skipped in data services list — provisioned by CAII"
         continue
      fi
      services_to_deploy+=("$service")
   done

   if [ "${#services_to_deploy[@]}" -eq 0 ]; then
      hol_info "No data services selected"
      return 0
   fi

   hol_parallel_start
   hol_info "Services: ${services_to_deploy[*]}"

   local pids=()
   for service in "${services_to_deploy[@]}"; do
      deploy_single_data_service "$service" &
      pids+=($!)
   done

   wait_for_pids "${pids[@]}"
}
#--------------------------------------------------------------------------------------------------#
disable_data_services() {
   local selected_services="${enable_data_services//[/}"
   selected_services="${selected_services//]/}"
   selected_services=$(echo "$selected_services" | tr '[:upper:]' '[:lower:]')

   IFS=',' read -ra data_services <<<"$selected_services"
   local services_to_disable=()
   local service

   for service in "${data_services[@]}"; do
      service=$(echo "$service" | xargs)
      [[ -z "$service" || "$service" == "none" ]] && continue
      services_to_disable+=("$service")
   done

   if [ "${#services_to_disable[@]}" -eq 0 ]; then
      hol_info "No data services to disable"
      return 0
   fi

   hol_subsection "Disabling data services in parallel" "🗑️"
   hol_info "Services: ${services_to_disable[*]}"

   local pids=()
   for service in "${services_to_disable[@]}"; do
      disable_single_data_service "$service" &
      pids+=($!)
   done

   wait_for_pids "${pids[@]}"
}
#--------------------------------------------------------------------------------------------------#
