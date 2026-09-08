#!/bin/bash
# *************************************************************************************************************#
# Setting required path and variables.

HOL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hol-output.sh
source "${HOL_LIB_DIR}/hol-output.sh"

#TF_QUICKSTART_VERSION=v0.8.0
USER_CONFIG_FILE="/userconfig/configfile"
KEYGEN_TF_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/keypair_gen
KC_TF_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/cdp-kc-config/keycloak_terraform_config
KC_ANS_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/cdp-kc-config/keycloak_ansible_config
DS_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/cdp-data-services
ENHANCEMENTS_TF_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/aws_enhancements/
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
         "AWS_REGION"
         #"AWS_KEY_PAIR"
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
         AWS_REGION)
            aws_region=$(echo $value | tr '[:upper:]' '[:lower:]')
            ;;
         AWS_KEY_PAIR)
            aws_key_pair=$(echo $value | tr '[:upper:]' '[:lower:]')
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

   # Call the function with the user-provided config file as an argument
   check_config "$USER_CONFIG_FILE"
   hol_ok "Configfile validated — input parameters verified"
}
#--------------------------------------------------------------------------------------------------------------#
# Function for checking .pem file.
key_pair_file() {
   USER_NAMESPACE=$workshop_name
   # Checking if SSH Keypair File exists.
   if [[ ! -f "/userconfig/$aws_key_pair.pem" ]]; then
      hol_fail "SSH key pair file not found: /userconfig/$aws_key_pair.pem" 9999
   else
      hol_step "Copying PEM file to user namespace"
      cp -pf "/userconfig/$aws_key_pair.pem" "/userconfig/.$USER_NAMESPACE/"
      hol_ok "SSH key pair copied"
   fi
}

check_key_pair() {
   USER_NAMESPACE=$workshop_name
   # Check if aws_key_pair exists as input
   # echo "USER_NAMESPACE: ${USER_NAMESPACE}"
   if [[ -z "$aws_key_pair" ]]; then
      # If keypair is empty, check if it's already generated and stored internally
      if [[ -f "/userconfig/.$USER_NAMESPACE/keypair_gen/${workshop_name}-keypair.pem" ]]; then
         export aws_key_pair=${workshop_name}-keypair
         hol_ok "Using previously generated keypair: $aws_key_pair"
      else
         hol_info "No AWS key pair provided — generating a new keypair"
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
# Function to verify AWS pre-requisites
aws_prereq() {
   vpc_limit=$(aws service-quotas get-service-quota \
      --service-code vpc \
      --output json \
      --region $aws_region \
      --quota-code L-F678F1CE | jq -r '.[]["Value"]' | cut -d'.' -f1)

   vpc_used=$(aws ec2 describe-vpcs --output json --region $aws_region | jq -r '.[] | length')
   hol_check_info "VPC count in ${aws_region}: ${vpc_used}/${vpc_limit}"

   if [ $vpc_limit -gt $vpc_used ]; then
      hol_check_pass "VPC quota available"
   else
      hol_quota_fail "VPC limit reached in ${aws_region}. Choose another region or remove unused VPCs."
   fi
   eip_limit=$(aws service-quotas get-service-quota \
      --service-code ec2 \
      --output json \
      --region $aws_region \
      --quota-code L-0263D0A3 | jq -r '.[]["Value"]' | cut -d'.' -f1)
   eip_used=$(aws ec2 describe-addresses --output json --region $aws_region | jq -r '.[] | length')
   hol_check_info "Elastic IP count in ${aws_region}: ${eip_used} (need 5 free)"

   if [[ $(($eip_limit - $eip_used)) -ge 5 ]]; then
      hol_check_pass "Elastic IP quota available"
   else
      hol_quota_fail "Not enough free Elastic IPs in ${aws_region}. Choose another region or release unused EIPs."
   fi
   # Check current bucket count
   bucket_count=$(aws s3api list-buckets --query "Buckets | length(@)" --output text)
   hol_check_info "S3 bucket count: ${bucket_count}"

   remaining_buckets=$((100 - bucket_count))

   if [ $remaining_buckets -le 0 ]; then
      bucket_name="test-bucket-$(date +%s)"
      aws s3api create-bucket --bucket $bucket_name --region us-east-1 &>/dev/null

      if [ $? -eq 0 ]; then
         aws s3api delete-bucket --bucket $bucket_name --region us-east-1
         if [ $? -eq 0 ]; then
            hol_check_pass "S3 bucket quota available"
         fi
      else
         hol_quota_fail "S3 bucket limit reached. Increase quota or remove unused buckets."
      fi
   else
      hol_check_pass "S3 bucket quota available"
   fi
}
#---------------------------------------------------------------------------------------------------------------------#
# Function to validate if resources are already present on AWS.
check_aws_sg_exists() {
   sg_name="$1"
   # Checking if Security Group exists.
   local sg_group_info=$(aws ec2 describe-security-groups --filters "Name=group-name,Values='$sg_name'" --region $aws_region --output text 2>/dev/null)
   # Validating the output
   if [[ -n $sg_group_info ]]; then
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
# Function to provision EC2 Instance for Keycloak
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
      -var "keypair_name=$workshop_name" \
      -var "aws_key_pair=$aws_key_pair" \
      -var "aws_region=$aws_region"
   RETURN=$?
   if [ $RETURN -eq 0 ]; then
      export aws_key_pair=$(terraform output -raw aws_key_pair_output) #updated the value of aws_key_pair if initially not exists
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
      -var "keypair_name=$workshop_name" \
      -var "aws_key_pair=$aws_key_pair" \
      -var "aws_region=$aws_region"
   RETURN=$?
   if [ $RETURN -eq 0 ]; then
      rm -rf /userconfig/.$USER_NAMESPACE/keypair_gen
      return 0
   else
      return 1
   fi
}

setup_keycloak_ec2() {
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

   hol_subsection "Running Terraform for Keycloak" "🏗️"
   # Run Terraform to provision Keycloak instance
   if check_aws_sg_exists "$sg_name"; then
      hol_warn "Security group '$sg_name' exists — using '$sg_name-$workshop_name-sg'"
      sg_name="$sg_name-$workshop_name"
   fi

   terraform init
   # Extract only the first IP for Keycloak (admin access only)
   kc_ip=$(echo "$local_ip" | cut -d',' -f1)

   terraform apply -auto-approve \
      -var "workshop_name=$workshop_name" \
      -var "local_ip=$kc_ip" \
      -var "instance_keypair=$aws_key_pair" \
      -var "aws_region=$aws_region" \
      -var "domain=$domain" \
      -var "wildcard_fullchain=$FULLCHAIN" \
      -var "wildcard_privkey=$PRIVKEY" \
      -var "kc_security_group=$sg_name" \
      -var "keycloak_admin_password=$keycloak__admin_password"

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
# Function to rollback keycloack EC2 Instance in case of failure during provision.
destroy_keycloak() {
   USER_NAMESPACE=$workshop_name
   hol_subsection "Destroying Keycloak" "🔐"
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
      -var "instance_keypair=$aws_key_pair" \
      -var "aws_region=$aws_region" \
      -var "kc_security_group=$sg_name" \
      -var "keycloak_admin_password=$keycloak__admin_password"
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
# Function to provision CDP Environment.
provision_cdp() {
   hol_banner "Provisioning CDP environment" "☁️"
   sleep 10
   USER_NAMESPACE=$workshop_name
   mkdir -p /userconfig/.$USER_NAMESPACE
   git clone https://github.com/cloudera-labs/cdp-tf-quickstarts.git -b $TF_QUICKSTART_VERSION --single-branch --depth 1 /userconfig/.$USER_NAMESPACE/cdp-tf-quickstarts &>/dev/null
   cd /userconfig/.$USER_NAMESPACE/cdp-tf-quickstarts
   git sparse-checkout init --cone
   git sparse-checkout set aws
   git checkout @ &>/dev/null
   cd /userconfig/.$USER_NAMESPACE/cdp-tf-quickstarts/aws

   # Convert comma-separated IPs into properly quoted Terraform list elements
   cdp_cidr=$(echo "$local_ip" | sed 's/,/\",\"/g')
   cdp_cidr="\"${cdp_cidr}\""

   #Adding outputs in quickstart outputs.tf
   file="outputs.tf"

   # Check if the public subnet output already exists
   public_subnet=$(grep "aws_public_subnet_ids" "$file")

   # Check if the private subnet output already exists
   private_subnet=$(grep "aws_private_subnet_ids" "$file")

   # Check if the bucket_name output already exists
   bucket_name=$(grep "aws_log_storage_location" "$file")

   # Append the public subnet output if it does not exist
   if [ -z "$public_subnet" ]; then
      cat <<EOF >>"$file"
output "aws_public_subnet_ids" {
  value = module.cdp_aws_prereqs.aws_public_subnet_ids
}
EOF
   fi
   # Append the private subnet output if it does not exist
   if [ -z "$private_subnet" ]; then
      cat <<EOF >>"$file"
output "aws_private_subnet_ids" {
  value = module.cdp_aws_prereqs.aws_private_subnet_ids
}
EOF
   fi
   # Append the bucket_name output if it does not exist
   if [ -z "$bucket_name" ]; then
      cat <<EOF >>"$file"
output "log_storage_bucket_name" {
  description = "The S3 bucket name extracted from the aws_log_storage_location string"
  value       = element(split("/", module.cdp_aws_prereqs.aws_log_storage_location), 2)
}
EOF
   fi
   terraform init

   # Default to empty map if ENV_TAGS not provided in configfile
   env_tags="${env_tags:-{}}"

   TFVARS_FILE="/tmp/env_tags_${workshop_name}.tfvars"

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

   hol_subsection "Generated Terraform env_tags" "🏷️"
   cat "$TFVARS_FILE"

   local cdp_tf_apply_args=(
      -var "env_prefix=${workshop_name}"
      -var "aws_region=${aws_region}"
      -var "aws_key_pair=${aws_key_pair}"
      -var "deployment_template=${deployment_template}"
      -var "ingress_extra_cidrs_and_ports={cidrs = [${cdp_cidr}],ports = [443, 22]}"
      -var "datalake_version=${datalake_version}"
      -var-file="${TFVARS_FILE}"
   )

   hol_subsection "Running Terraform for CDP environment & datalake" "☁️"
   terraform apply --auto-approve "${cdp_tf_apply_args[@]}"

   if [ $? -ne 0 ]; then
      return 1
   fi

   assign_environment_base_roles

   cdp_provision_status=0
   if [ $cdp_provision_status -eq 0 ]; then
      export ENV_PUBLIC_SUBNETS=$(terraform output -json aws_public_subnet_ids)
      export ENV_PRIVATE_SUBNETS=$(terraform output -json aws_private_subnet_ids)

      hol_kv "Public subnets" "$ENV_PUBLIC_SUBNETS"
      hol_kv "Private subnets" "$ENV_PRIVATE_SUBNETS"

      ENV_PUBLIC_SUBNETS=$(terraform output -json aws_public_subnet_ids | jq -c '.[0:3]')
      hol_info "First 3 public subnets (CDW/CDF): $ENV_PUBLIC_SUBNETS"
      ENV_PRIVATE_SUBNETS=$(terraform output -json aws_private_subnet_ids | jq -c '.[0:3]')
      hol_info "First 3 private subnets (CDW/CDF): $ENV_PRIVATE_SUBNETS"

      export BUCKET_NAME=$(terraform output -raw log_storage_bucket_name)

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

      aws_enhancements #calling aws_enahancements function
      aws_enhancements_status=$?
      if [ $aws_enhancements_status -ne 0 ]; then
         hol_warn "AWS enhancements failed to apply — check logs for details"
      fi

      return 0
   else
      return 1
   fi

}

#Add enhancements
aws_enhancements() {
   hol_subsection "Adding AWS enhancements" "✨"
   USER_NAMESPACE=$workshop_name
   mkdir -p /userconfig/.$USER_NAMESPACE

   if [ ! -d "/userconfig/.$USER_NAMESPACE/$ENHANCEMENTS_TF_CONFIG_DIR" ]; then
      cp -R "$ENHANCEMENTS_TF_CONFIG_DIR" "/userconfig/.$USER_NAMESPACE/"
   fi

   cd /userconfig/.$USER_NAMESPACE/aws_enhancements/s3_enhancements
     terraform init
     terraform apply -auto-approve \
         -var="log_bucket_name=$BUCKET_NAME" \
         -var="aws_region=$aws_region"
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
   cdp iam update-group --group-name $workshop_name-aw-cdp-user-group --sync-membership-on-user-login
}
#--------------------------------------------------------------------------------------------------#
# Function to destroy CDP Environment.
destroy_cdp() {
   USER_NAMESPACE=$workshop_name
   hol_banner "Destroying CDP environment infrastructure" "🗑️"
   cd /userconfig/.$USER_NAMESPACE/cdp-tf-quickstarts/aws
   # Convert comma-separated IPs into properly quoted Terraform list elements
   cdp_cidr=$(echo "$local_ip" | sed 's/,/\",\"/g')
   cdp_cidr="\"${cdp_cidr}\""

   terraform init
   terraform destroy --auto-approve \
      -var "env_prefix=${workshop_name}" \
      -var "aws_region=${aws_region}" \
      -var "aws_key_pair=${aws_key_pair}" \
      -var "deployment_template=${deployment_template}" \
      -var "ingress_extra_cidrs_and_ports={cidrs = [${cdp_cidr}],ports = [443, 22]}"
      
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
   destroy_cdp
   cdp_destroy_status=$?
   if [[ "$provision_keycloak" == "yes" && "$cdp_destroy_status" -eq 0 ]]; then
      destroy_keycloak
      keycloak_destroy_status=$?
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
      hol_session_name=$workshop_name-aw-cdp-user-group \
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
         --groups "$workshop_name-aw-cdp-user-group" \
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
      hol_session_name=$workshop_name-aw-cdp-user-group"
   sleep 5
   hol_step "Fetching workshop user details for report..."
   sample_keycloak_user1=$(cat /tmp/$workshop_name-aw-cdp-user-group.json | jq -r '.[0].username')
   sample_keycloak_user2=$(cat /tmp/$workshop_name-aw-cdp-user-group.json | jq -r '.[1].username')
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
   
   if [[ -f /userconfig/keycloak_ip ]]; then
      KEYCLOAK_SERVER_IP=$(cat /userconfig/keycloak_ip)
      hol_info "Keycloak server IP: $KEYCLOAK_SERVER_IP"
      cd /userconfig/.$USER_NAMESPACE/keycloak_ansible_config
      ansible-playbook keycloak_hol_user_teardown.yml --extra-vars \
         "keycloak__admin_username=admin \
         keycloak__admin_password=$keycloak__admin_password \
         keycloak__domain=https://$KEYCLOAK_SERVER_IP \
         hol_keycloak_realm=master \
         hol_session_name=$workshop_name-aw-cdp-user-group"
      sleep 10
   else
      hol_skip "Keycloak IP file not found — assuming Keycloak already destroyed"
   fi

   hol_subsection "Removing IDP from CDP tenant" "🔗"
   cdp iam delete-saml-provider --saml-provider-name $workshop_name
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

   ansible-playbook $DS_CONFIG_DIR/enable-cdw.yml --extra-vars \
      "cdp_env_name=$workshop_name-cdp-env \
      env_lb_public_subnet=$ENV_PUBLIC_SUBNETS \
      env_wrkr_private_subnet=$ENV_PRIVATE_SUBNETS \
      workshop_name=$workshop_name \
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
   DEFAULT_CDE_INSTANCE_TYPE="m5.2xlarge"
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
   local extra_vars_file="/tmp/cdf_extra_vars_${workshop_name}.json"

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
   set_resource_roles $workshop_name-aw-cdp-user-group $workshop_name-cdp-env "${resource_roles[@]}"
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
         set_resource_roles $workshop_name-aw-cdp-user-group $workshop_name-cdp-env "${resource_roles[@]}"
      fi
      ;;
   cde)
      hol_init_service "cde"
      DEFAULT_CDE_INSTANCE_TYPE="m5.2xlarge"
      DEFAULT_CDE_INITIAL_INSTANCES=10
      DEFAULT_CDE_MIN_INSTANCES=10
      DEFAULT_CDE_MAX_INSTANCES=40
      DEFAULT_CDE_SPARK_VERSION="SPARK3"
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
         set_resource_roles $workshop_name-aw-cdp-user-group $workshop_name-cdp-env "${resource_roles[@]}"
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
         set_resource_roles $workshop_name-aw-cdp-user-group $workshop_name-cdp-env "${resource_roles[@]}"
      fi
      ;;
   cdf)
      hol_init_service "cdf"
      DEFAULT_CDF_INSTANCE_TYPE="m5.2xlarge"
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
         set_resource_roles $workshop_name-aw-cdp-user-group $workshop_name-cdp-env "${resource_roles[@]}"
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
