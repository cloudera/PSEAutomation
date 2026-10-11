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
        keycloak_preexisting=false
        if hol_keycloak_already_provisioned; then
            keycloak_preexisting=true
            hol_info "Keycloak already provisioned — reconciling Terraform configuration"
        fi
        setup_keycloak_ec2
        if [ $? -ne 0 ]; then
            if [[ "$keycloak_preexisting" == true ]]; then
                hol_warn "Keycloak update failed — preserving the pre-existing instance and Terraform state"
            else
                hol_warn "Keycloak provisioning failed — rolling back"
                destroy_keycloak
            fi
            hol_provision_failed "$workshop_name"
        else
            hol_milestone "Keycloak Server Provisioned" "🔐"
        fi
    else
        hol_skip "Keycloak provisioning skipped (configfile)"
    fi
    sleep 10
    cdp_environment_preexisting=false
    cdp_environment_status=""
    cdp_status_lookup_rc=0
    cdp_environment_status=$(get_cdp_environment_status) || cdp_status_lookup_rc=$?
    cdp_environment_status=$(printf '%s' "$cdp_environment_status" | tr '[:lower:]' '[:upper:]')
    run_cdp_terraform=false

    if [[ "$cdp_status_lookup_rc" -eq 1 ]]; then
        hol_warn "Unable to determine CDP environment status — refusing Terraform apply or destroy"
        hol_provision_failed "$workshop_name"
    elif [[ "$cdp_status_lookup_rc" -eq 2 ]]; then
        if cdp_environment_exists; then
            hol_warn "CDP reports environment absent but Terraform state exists — refusing automatic recreation; manual recovery is required"
            hol_provision_failed "$workshop_name"
        fi
        hol_info "CDP environment is confirmed absent and no Terraform state exists — provisioning a new stack"
        run_cdp_terraform=true
    elif [[ "$cdp_environment_status" == "AVAILABLE" ]]; then
        cdp_environment_preexisting=true
        if ! cdp_aws_infrastructure_healthy; then
            hol_warn "CDP reports AVAILABLE, but its Terraform-managed VPC or subnets are missing — refusing Terraform apply and destroy; manual environment recovery is required"
            hol_provision_failed "$workshop_name"
        fi
        hol_skip "CDP environment '${workshop_name}-cdp-env' is healthy (AVAILABLE) — skipping CDP Terraform"
        hol_milestone "CDP Environment Available" "☁️"
    elif [[ "$cdp_environment_status" =~ (FAILED|ERROR|UNHEALTHY|UNAVAILABLE|CORRUPT|NODE_FAILURE) ]]; then
        cdp_environment_preexisting=true
        hol_warn "CDP environment is explicitly unhealthy (status=${cdp_environment_status}) — allowing guarded Terraform reconciliation"
        run_cdp_terraform=true
    else
        hol_warn "CDP environment status '${cdp_environment_status:-unknown}' is not a safe Terraform reconciliation state — refusing Terraform apply or destroy"
        hol_provision_failed "$workshop_name"
    fi

    if [[ "$run_cdp_terraform" == true ]]; then
        provision_cdp
        if [ $? -ne 0 ]; then
            hol_warn "CDP provisioning failed — preserving all CDP, AWS, Keycloak, and Terraform resources for safe recovery"
            hol_provision_failed "$workshop_name"
        else
            hol_milestone "CDP Environment Provisioned" "☁️"
        fi
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

    hol_milestone "Infrastructure Provisioned" "🎉"
    hol_info "Workshop access details: /userconfig/${workshop_name}.txt (attached to Jenkins email when run from CI)"
    ;;
destroy)
    hol_banner "HoL Destroy Pipeline" "🗑️"
    validating_variables
    hol_subsection "Deleting CAII, Data Hubs, and data services in parallel" "🗑️"
    if [ "$provision_caii" == "yes" ]; then
        destroy_cai_inference &
    else
        hol_skip "CAII deletion disabled (PROVISION_CAII is not yes)"
        true &
    fi
    caii_delete_pid=$!

    if [[ "${delete_datahubs:-true}" == "true" ]]; then
        delete_environment_datahubs &
    else
        hol_skip "Data Hub deletion disabled (DELETE_DATAHUBS=false)"
        true &
    fi
    datahub_delete_pid=$!
    disable_data_services &
    data_services_delete_pid=$!

    caii_delete_status=0
    datahub_delete_status=0
    data_services_delete_status=0
    wait "$caii_delete_pid" || caii_delete_status=$?
    wait "$datahub_delete_pid" || datahub_delete_status=$?
    wait "$data_services_delete_pid" || data_services_delete_status=$?
    if [[ "$caii_delete_status" -ne 0 || "$datahub_delete_status" -ne 0 || "$data_services_delete_status" -ne 0 ]]; then
        hol_warn "CDP teardown failed (CAII=${caii_delete_status}, Data Hubs=${datahub_delete_status}, data services=${data_services_delete_status})"
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
