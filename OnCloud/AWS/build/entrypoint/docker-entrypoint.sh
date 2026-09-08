#!/bin/bash
# ***************************************************************************************************#
source /usr/local/bin/hol-functions.sh
# Setting required path and variables.
USER_CONFIG_FILE="/userconfig/configfile"
TERRAFORM_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/cdp-kc-config/keycloak_terraform_config
DS_CONFIG_DIR=$HOME_DIR/cdp-wrkshps-quickstarts/cdp-data-services
USER_ACTION=$1
hol_startup_banner
# Handling the User Action ('provision' or 'destroy').
case $USER_ACTION in
provision)
    hol_banner "HoL Provision Pipeline" "🚀"
    validating_variables
    if [[ -n "$aws_key_pair" ]]; then
        key_pair_file
    else
        hol_skip "No AWS key pair provided — skipping SSH key file check"
    fi
    #setup_aws_and_cdp_profile
    hol_subsection "AWS pre-requisites" "☁️"
    aws_prereq
    hol_subsection "CDP pre-requisites" "🔐"
    cdp_prereq
    check_key_pair
    if [ "$provision_keycloak" == "yes" ]; then
        # setup_keycloak_ec2 $keycloak_sg_name
        setup_keycloak_ec2
        if [ $? -ne 0 ]; then
            hol_warn "Keycloak provisioning failed — rolling back"
            destroy_keycloak
            hol_provision_failed "$workshop_name"
        else
            hol_milestone "Keycloak Server Provisioned" "🔐"
        fi
    else
        hol_skip "Keycloak provisioning skipped (configfile)"
    fi
    sleep 10
    provision_cdp
    if [ $? -ne 0 ]; then
        hol_warn "CDP environment provisioning failed — rolling back"
        destroy_cdp
        if [ "$provision_keycloak" == "yes" ]; then
            destroy_keycloak
        fi
        hol_provision_failed "$workshop_name"
    else
        hol_milestone "CDP Environment Provisioned" "☁️"
    fi
    update_cdp_user_group
    if [ "$provision_keycloak" == "yes" ]; then
        cdp_idp_setup_user
    fi

    parallel_pids=()
    if [ "$provision_caii" == "yes" ]; then
        sleep 30
        hol_subsection "CAII provisioning" "🧠"
        provision_cai_inference &
        parallel_pids+=($!)
    fi

    enable_data_services &
    parallel_pids+=($!)

    parallel_failed=0
    for pid in "${parallel_pids[@]}"; do
        wait "$pid" || parallel_failed=1
    done
    if [ "$parallel_failed" -ne 0 ]; then
        hol_provision_failed "$workshop_name"
    fi

    hol_milestone "Infrastructure Provisioned" "🎉"
    ;;
destroy)
    hol_banner "HoL Destroy Pipeline" "🗑️"
    validating_variables
    if [ "$provision_caii" == "yes" ]; then
        hol_subsection "CAII teardown" "🧠"
        destroy_cai_inference
    fi
    disable_data_services
    if [ "$provision_keycloak" == "yes" ]; then
        cdp_idp_user_teardown
    fi
    destroy_hol_infra
    hol_banner "Infrastructure destroyed" "✅"
    hol_ok "Workshop '${workshop_name}' teardown completed"
    ;;
*)
    hol_fail "Invalid action '${USER_ACTION}'. Valid values: provision, destroy"
    ;;

esac
# ***********************************************************************************************#
