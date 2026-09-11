#!/usr/bin/env bash
# Assign environment-scoped admin roles so the Jenkins/CDP machine user (and
# optionally the build user) can manage data services during provision/destroy.
set -uo pipefail

WORKSHOP_NAME="${WORKSHOP_NAME:-}"
CDP_ENV_NAME="${CDP_ENV_NAME:-}"
BUILD_USER_ID="${BUILD_USER_ID:-}"
CDP_MACHINE_USERNAME="${CDP_MACHINE_USERNAME:-psejenkins}"
ASSIGN_BUILD_USER="${ASSIGN_BUILD_USER:-true}"
ASSIGN_MACHINE_USER="${ASSIGN_MACHINE_USER:-true}"
ASSIGN_CALLER="${ASSIGN_CALLER:-true}"

if [ -z "$CDP_ENV_NAME" ] && [ -n "$WORKSHOP_NAME" ]; then
   CDP_ENV_NAME="$(echo "$WORKSHOP_NAME" | tr '[:upper:]' '[:lower:]')-cdp-env"
fi

if [ -z "$CDP_ENV_NAME" ]; then
   echo "WARN: CDP_ENV_NAME/WORKSHOP_NAME not set — skipping role assignment."
   exit 0
fi

CDP_ENV_CRN="$(cdp environments describe-environment --environment-name "$CDP_ENV_NAME" 2>/dev/null | jq -r '.environment.crn // empty')"
if [ -z "$CDP_ENV_CRN" ] || [ "$CDP_ENV_CRN" = "null" ]; then
   echo "INFO: Environment '$CDP_ENV_NAME' not found yet — skipping role assignment."
   exit 0
fi

ENV_ADMIN_ROLES=(
   EnvironmentAdmin
   Owner
   DFFlowAdmin
   DWAdmin
   DEAdmin
   MLAdmin
)

get_crn_resource_role() {
   local role_name="$1"
   cdp iam list-resource-roles 2>/dev/null \
      | jq -r --arg role "$role_name" '.resourceRoles[]? | select(.crn | endswith(":" + $role)) | .crn' \
      | head -1
}

resolve_machine_user_crn() {
   local machine_user_name="$1"
   cdp iam list-machine-users --max-items 10000 2>/dev/null \
      | jq -r --arg name "$machine_user_name" '.machineUsers[]? | select(.machineUserName == $name) | .crn' \
      | head -1
}

resolve_human_user_crn() {
   local workload_username="$1"
   cdp iam list-users --max-items 10000 2>/dev/null \
      | jq -r --arg name "$workload_username" '.users[]? | select(.workloadUsername == $name) | .userId' \
      | head -1
}

machine_user_has_resource_role() {
   local machine_user_crn="$1"
   local role_name="$2"
   cdp iam list-machine-user-assigned-resource-roles --machine-user "$machine_user_crn" 2>/dev/null \
      | jq -e --arg role ":$role_name" --arg env "$CDP_ENV_CRN" \
         '.resourceRoles[]? | select(.crn | endswith($role)) | select(.resourceCrn == $env)' >/dev/null
}

human_user_has_resource_role() {
   local user_crn="$1"
   local role_name="$2"
   cdp iam list-user-assigned-resource-roles --user "$user_crn" 2>/dev/null \
      | jq -e --arg role ":$role_name" --arg env "$CDP_ENV_CRN" \
         '.resourceRoles[]? | select(.crn | endswith($role)) | select(.resourceCrn == $env)' >/dev/null
}

assign_machine_user_roles() {
   local machine_user_name="$1"
   local machine_user_crn="$2"
   local role_name role_crn err_file assign_failed=0

   echo "Assigning environment roles to machine user '${machine_user_name}' on ${CDP_ENV_NAME}"

   for role_name in "${ENV_ADMIN_ROLES[@]}"; do
      if machine_user_has_resource_role "$machine_user_crn" "$role_name"; then
         echo "  ✓ ${role_name} (already assigned)"
         continue
      fi

      role_crn="$(get_crn_resource_role "$role_name")"
      if [ -z "$role_crn" ]; then
         echo "  WARN: Role '${role_name}' not found — skipping"
         continue
      fi

      err_file="$(mktemp)"
      if cdp iam assign-machine-user-resource-role \
         --machine-user "$machine_user_crn" \
         --resource-role-crn "$role_crn" \
         --resource-crn "$CDP_ENV_CRN" >"$err_file" 2>&1; then
         echo "  ✓ ${role_name} assigned"
      elif grep -qiE 'ALREADY_EXISTS|already assigned' "$err_file"; then
         echo "  ✓ ${role_name} (already assigned)"
      else
         echo "  ✗ Failed to assign ${role_name}:"
         sed 's/^/    /' "$err_file"
         assign_failed=1
      fi
      rm -f "$err_file"
   done

   return "$assign_failed"
}

assign_human_user_roles() {
   local workload_username="$1"
   local user_crn="$2"
   local role_name role_crn err_file assign_failed=0

   echo "Assigning environment roles to user '${workload_username}' on ${CDP_ENV_NAME}"

   for role_name in "${ENV_ADMIN_ROLES[@]}"; do
      if human_user_has_resource_role "$user_crn" "$role_name"; then
         echo "  ✓ ${role_name} (already assigned)"
         continue
      fi

      role_crn="$(get_crn_resource_role "$role_name")"
      if [ -z "$role_crn" ]; then
         echo "  WARN: Role '${role_name}' not found — skipping"
         continue
      fi

      err_file="$(mktemp)"
      if cdp iam assign-user-resource-role \
         --user "$user_crn" \
         --resource-role-crn "$role_crn" \
         --resource-crn "$CDP_ENV_CRN" >"$err_file" 2>&1; then
         echo "  ✓ ${role_name} assigned"
      elif grep -qiE 'ALREADY_EXISTS|already assigned' "$err_file"; then
         echo "  ✓ ${role_name} (already assigned)"
      else
         echo "  ✗ Failed to assign ${role_name}:"
         sed 's/^/    /' "$err_file"
         assign_failed=1
      fi
      rm -f "$err_file"
   done

   return "$assign_failed"
}

assign_failed=0
assigned_machine_users=()

if [ "$ASSIGN_MACHINE_USER" = "true" ]; then
   machine_user_crn="$(resolve_machine_user_crn "$CDP_MACHINE_USERNAME")"
   if [ -n "$machine_user_crn" ]; then
      assign_machine_user_roles "$CDP_MACHINE_USERNAME" "$machine_user_crn" || assign_failed=1
      assigned_machine_users+=("$CDP_MACHINE_USERNAME")
   else
      echo "WARN: Machine user '${CDP_MACHINE_USERNAME}' not found — skipping machine user role assignment."
   fi
fi

if [ "$ASSIGN_CALLER" = "true" ]; then
   caller_json="$(cdp iam get-user 2>/dev/null || true)"
   caller_crn="$(echo "$caller_json" | jq -r '.user.userId // empty')"
   caller_name="$(echo "$caller_json" | jq -r '.user.workloadUsername // .user.machineUserName // empty')"
   caller_is_machine="$(echo "$caller_json" | jq -r '.user.machineUser // false')"

   if [ -n "$caller_crn" ] && [ "$caller_crn" != "null" ]; then
      if [ "$caller_is_machine" = "true" ]; then
         if [[ ! " ${assigned_machine_users[*]} " =~ " ${caller_name} " ]]; then
            assign_machine_user_roles "${caller_name:-caller}" "$caller_crn" || assign_failed=1
         fi
      else
         assign_human_user_roles "${caller_name:-caller}" "$caller_crn" || assign_failed=1
      fi
   fi
fi

if [ "$ASSIGN_BUILD_USER" = "true" ] && [ -n "$BUILD_USER_ID" ]; then
   build_workload_username="${BUILD_USER_ID//_/.}"
   build_user_crn="$(resolve_human_user_crn "$build_workload_username")"
   if [ -n "$build_user_crn" ]; then
      assign_human_user_roles "$build_workload_username" "$build_user_crn" || assign_failed=1
   else
      echo "WARN: Build user '${build_workload_username}' not found — skipping build user role assignment."
   fi
fi

cdp environments sync-all-users --environment-name "$CDP_ENV_NAME" >/dev/null 2>&1 || true
cdp environments sync-id-broker-mappings --environment-name "$CDP_ENV_NAME" >/dev/null 2>&1 || true

if [ "$assign_failed" -ne 0 ]; then
   exit 1
fi
