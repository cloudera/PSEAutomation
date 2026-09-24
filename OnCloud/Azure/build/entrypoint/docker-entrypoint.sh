#!/bin/bash
# ***************************************************************************************************#
source /usr/local/bin/hol-functions.sh
hol_apply_terraform_env
hol_fixup_cloudera_cloud_python
configure_git_for_userconfig
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
    ensure_aws_cli_for_dns
    if [[ -n "$ssh_key_name" ]]; then
        key_pair_file
    else
        hol_skip "No SSH key name provided — skipping SSH key file check"
    fi
    #setup_aws_and_cdp_profile
    hol_subsection "Azure pre-requisites" "☁️"
    azure_prereq
    hol_subsection "CDP pre-requisites" "🔐"
    cdp_prereq
    check_key_pair
    sleep 10
    cdp_environment_preexisting=false
    if cdp_environment_exists; then
        cdp_environment_preexisting=true
        hol_info "Existing CDP environment detected — rerun failures will not trigger infrastructure rollback"
    fi
    provision_cdp
    if [ $? -ne 0 ]; then
        if [[ "$cdp_environment_preexisting" == true ]]; then
            hol_warn "CDP environment update failed — preserving the pre-existing environment and Terraform state"
        else
            hol_warn "New CDP environment provisioning failed — rolling back resources created by this run"
            destroy_cdp
        fi
        hol_provision_failed "$workshop_name"
    else
        write_workshop_cdp_outputs
        hol_milestone "CDP Environment Provisioned" "☁️"
    fi
    if [ "$provision_keycloak" == "yes" ]; then
        if hol_keycloak_already_provisioned; then
            hol_skip "Keycloak already provisioned for this workshop"
            hol_milestone "Keycloak Server Provisioned" "🔐"
        else
            setup_keycloak_vm
            if [ $? -ne 0 ]; then
                hol_warn "Keycloak provisioning failed — rolling back"
                destroy_keycloak
                hol_provision_failed "$workshop_name"
            else
                wait_for_keycloak_ready || hol_provision_failed "$workshop_name"
            fi
            hol_milestone "Keycloak Server Provisioned" "🔐"
        fi
    else
        hol_skip "Keycloak provisioning skipped (configfile)"
    fi
    update_cdp_user_group
    if [ "$provision_keycloak" == "yes" ]; then
        cdp_idp_setup_user || hol_provision_failed "$workshop_name"
    fi

    parallel_pids=()
    if [ "$provision_caii" == "yes" ]; then
        sleep 30
        hol_subsection "CAII provisioning" "🧠"
        provision_cai_inference &
        parallel_pids+=($!)
    fi

    hol_enable_data_services &
    parallel_pids+=($!)

    parallel_failed=0
    for pid in "${parallel_pids[@]}"; do
        wait "$pid" || parallel_failed=1
    done
    if [ "$parallel_failed" -ne 0 ]; then
        hol_provision_failed "$workshop_name"
    fi

    write_workshop_data_service_outputs
    hol_milestone "Infrastructure Provisioned" "🎉"
    hol_info "Workshop access details: /userconfig/${workshop_name}.txt (attached to Jenkins email when run from CI)"
    ;;
destroy)
    hol_banner "HoL Destroy Pipeline" "🗑️"
    validating_variables
    ensure_aws_cli_for_dns
    setup_azure_cli_auth
    if [ "$provision_caii" == "yes" ]; then
        hol_subsection "CAII teardown" "🧠"
        destroy_cai_inference || hol_destroy_failed "$workshop_name"
    fi
    hol_subsection "Deleting Data Hubs and data services in parallel" "🗑️"
    if [[ "${delete_datahubs:-true}" == "true" ]]; then
        delete_environment_datahubs &
    else
        hol_skip "Data Hub deletion disabled (DELETE_DATAHUBS=false)"
        true &
    fi
    datahub_delete_pid=$!
    disable_data_services &
    data_services_delete_pid=$!

    datahub_delete_status=0
    data_services_delete_status=0
    wait "$datahub_delete_pid" || datahub_delete_status=$?
    wait "$data_services_delete_pid" || data_services_delete_status=$?
    if [[ "$datahub_delete_status" -ne 0 || "$data_services_delete_status" -ne 0 ]]; then
        hol_warn "CDP teardown failed (Data Hubs=${datahub_delete_status}, data services=${data_services_delete_status})"
        hol_destroy_failed "$workshop_name"
    fi
    if [ "$provision_keycloak" == "yes" ]; then
        cdp_idp_user_teardown
    fi
    destroy_hol_infra
    if [ $? -ne 0 ]; then
        hol_destroy_failed "$workshop_name"
    fi
    hol_banner "Infrastructure destroyed" "✅"
    hol_ok "Workshop '${workshop_name}' teardown completed"
    ;;
*)
    hol_fail "Invalid action '${USER_ACTION}'. Valid values: provision, destroy"
    ;;

esac
# ***********************************************************************************************#
