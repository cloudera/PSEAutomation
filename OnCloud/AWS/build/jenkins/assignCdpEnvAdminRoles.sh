#!/usr/bin/env bash
# Assign environment-scoped admin roles to the active CDP API caller (~/.cdp) and optionally
# a Jenkins/docker human executor (BUILD_USER_ID). Invoked from Jenkins and from
# hol_assign_pipeline_cdp_env_admin_roles() in the provisioner (/usr/local/bin/assignCdpEnvAdminRoles.sh).
set -uo pipefail

WORKSHOP_NAME="${WORKSHOP_NAME:-}"
CDP_ENV_NAME="${CDP_ENV_NAME:-}"
BUILD_USER_ID="${BUILD_USER_ID:-}"
CDP_MACHINE_USERNAME="${CDP_MACHINE_USERNAME:-psejenkins}"
ASSIGN_BUILD_USER="${ASSIGN_BUILD_USER:-true}"
ASSIGN_MACHINE_USER="${ASSIGN_MACHINE_USER:-true}"
ASSIGN_CALLER="${ASSIGN_CALLER:-true}"

CALLER_IS_MACHINE=""
CALLER_CRN=""
CALLER_NAME=""
CALLER_WORKLOAD=""

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
   DFAdmin
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

read_cdp_access_key_id() {
   local cred_file profile
   if [ -n "${CDP_ACCESS_KEY_ID:-}" ]; then
      echo "$CDP_ACCESS_KEY_ID"
      return 0
   fi
   cred_file="${CDP_CREDENTIALS_FILE:-${HOME}/.cdp/credentials}"
   profile="${CDP_PROFILE:-default}"
   if [ ! -f "$cred_file" ]; then
      return 1
   fi
   awk -v profile="$profile" '
      /^\[/ { inprof = ($0 == "[" profile "]") }
      inprof && /^cdp_access_key_id=/ {
         sub(/^cdp_access_key_id=/, "")
         gsub(/^[ \t\r]+|[ \t\r]+$/, "")
         print
         exit
      }
   ' "$cred_file"
}

resolve_machine_user_by_access_key() {
   local access_key="$1"
   local json name crn
   [ -z "$access_key" ] && return 1
   json="$(cdp iam list-machine-users --max-items 10000 2>/dev/null || true)"
   name="$(echo "$json" | jq -r --arg ak "$access_key" '.machineUsers[]? | select(.accessKeyId == $ak) | .machineUserName' | head -1)"
   crn="$(echo "$json" | jq -r --arg ak "$access_key" '.machineUsers[]? | select(.accessKeyId == $ak) | .crn' | head -1)"
   if [ -z "$name" ] || [ -z "$crn" ]; then
      return 1
   fi
   CALLER_IS_MACHINE=true
   CALLER_NAME="$name"
   CALLER_CRN="$crn"
   echo "INFO: Resolved CDP API caller as machine user '${CALLER_NAME}' (matched ~/.cdp access key)."
   return 0
}

resolve_cdp_api_caller() {
   CALLER_IS_MACHINE=""
   CALLER_CRN=""
   CALLER_NAME=""
   CALLER_WORKLOAD=""

   local get_user_json err_file get_user_rc
   err_file="$(mktemp)"
   get_user_json="$(cdp iam get-user 2>"$err_file")"
   get_user_rc=$?

   if [ "$get_user_rc" -eq 0 ] && [ -n "$get_user_json" ] && echo "$get_user_json" | jq -e '.user.userId' >/dev/null 2>&1; then
      CALLER_CRN="$(echo "$get_user_json" | jq -r '.user.userId')"
      CALLER_IS_MACHINE="$(echo "$get_user_json" | jq -r '.user.machineUser // false')"
      if [ "$CALLER_IS_MACHINE" = "true" ]; then
         CALLER_NAME="$(echo "$get_user_json" | jq -r '.user.machineUserName // empty')"
         echo "INFO: Resolved CDP API caller as machine user '${CALLER_NAME}' (cdp iam get-user)."
      else
         CALLER_WORKLOAD="$(echo "$get_user_json" | jq -r '.user.workloadUsername // empty')"
         CALLER_NAME="$CALLER_WORKLOAD"
         echo "INFO: Resolved CDP API caller as user '${CALLER_NAME}' (cdp iam get-user)."
      fi
      rm -f "$err_file"
      return 0
   fi

   if [ -n "$CDP_MACHINE_USERNAME" ]; then
      CALLER_CRN="$(resolve_machine_user_crn "$CDP_MACHINE_USERNAME")"
      if [ -n "$CALLER_CRN" ]; then
         CALLER_IS_MACHINE=true
         CALLER_NAME="$CDP_MACHINE_USERNAME"
         echo "INFO: Resolved CDP API caller as machine user '${CALLER_NAME}' (CDP_MACHINE_USERNAME; get-user not usable for this credential)."
         rm -f "$err_file"
         return 0
      fi
   fi

   local access_key
   access_key="$(read_cdp_access_key_id || true)"
   if resolve_machine_user_by_access_key "$access_key"; then
      rm -f "$err_file"
      return 0
   fi

   echo "WARN: Could not resolve CDP API caller — get-user failed and no machine user matched the active CDP access key."
   if [ -s "$err_file" ]; then
      sed 's/^/  /' "$err_file" >&2
   fi
   rm -f "$err_file"
   return 1
}

workload_usernames_match() {
   local a="$1" b="$2"
   if [ -z "$a" ] || [ -z "$b" ]; then
      return 1
   fi
   if [ "$a" = "$b" ]; then
      return 0
   fi
   if [ "${a//_/.}" = "${b//_/.}" ]; then
      return 0
   fi
   return 1
}

caller_matches_build_user() {
   local build_workload="$1"
   if [ -z "$CALLER_NAME" ]; then
      return 1
   fi
   if [ "$CALLER_IS_MACHINE" = "true" ]; then
      if workload_usernames_match "$build_workload" "$CALLER_NAME" \
         || workload_usernames_match "${BUILD_USER_ID:-}" "$CALLER_NAME"; then
         return 0
      fi
      return 1
   fi
   if workload_usernames_match "$build_workload" "${CALLER_WORKLOAD:-$CALLER_NAME}" \
      || workload_usernames_match "${BUILD_USER_ID:-}" "${CALLER_WORKLOAD:-$CALLER_NAME}" \
      || workload_usernames_match "${BUILD_USER_ID:-}" "$CALLER_NAME"; then
      return 0
   fi
   return 1
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

human_user_already_assigned() {
   local workload_username="$1"
   local u
   for u in "${assigned_human_users[@]}"; do
      if workload_usernames_match "$u" "$workload_username"; then
         return 0
      fi
   done
   return 1
}

assign_human_user_by_workload() {
   local workload_username="$1"
   local user_crn

   if human_user_already_assigned "$workload_username"; then
      echo "INFO: User '${workload_username}' already received env admin roles in this run — skipping duplicate"
      return 0
   fi

   user_crn="$(resolve_human_user_crn "$workload_username")"
   if [ -n "$user_crn" ]; then
      assign_human_user_roles "$workload_username" "$user_crn" || return 1
      assigned_human_users+=("$workload_username")
   else
      echo "WARN: User '${workload_username}' not found — skipping role assignment."
   fi
   return 0
}

build_user_label=""
build_workload_username=""
if [ "$ASSIGN_BUILD_USER" = "true" ] && [ -n "$BUILD_USER_ID" ] \
   && ! workload_usernames_match "$BUILD_USER_ID" "$CDP_MACHINE_USERNAME"; then
   build_workload_username="${BUILD_USER_ID//_/.}"
   build_user_label="$BUILD_USER_ID"
fi

declare -A machine_user_crns=()
machine_user_order=()
assigned_human_users=()

add_machine_target() {
   local name="$1" crn="$2"
   if [ -z "$name" ] || [ -z "$crn" ]; then
      return 0
   fi
   if [ -n "${machine_user_crns[$name]+x}" ]; then
      return 0
   fi
   machine_user_crns[$name]="$crn"
   machine_user_order+=("$name")
}

add_human_target() {
   local workload="$1"
   local u
   if [ -z "$workload" ]; then
      return 0
   fi
   for u in "${human_workload_order[@]}"; do
      if workload_usernames_match "$u" "$workload"; then
         return 0
      fi
   done
   human_workload_order+=("$workload")
}

human_workload_order=()
assign_failed=0

if [ "$ASSIGN_MACHINE_USER" = "true" ]; then
   machine_user_crn="$(resolve_machine_user_crn "$CDP_MACHINE_USERNAME")"
   if [ -n "$machine_user_crn" ]; then
      add_machine_target "$CDP_MACHINE_USERNAME" "$machine_user_crn"
   else
      echo "WARN: Machine user '${CDP_MACHINE_USERNAME}' not found — skipping pipeline machine user role assignment."
   fi
fi

if [ "$ASSIGN_CALLER" = "true" ]; then
   if resolve_cdp_api_caller; then
      if [ "$CALLER_IS_MACHINE" = "true" ]; then
         add_machine_target "$CALLER_NAME" "$CALLER_CRN"
      else
         add_human_target "${CALLER_WORKLOAD:-$CALLER_NAME}"
      fi
   else
      assign_failed=1
   fi
fi

if [ -n "$build_workload_username" ] && ! caller_matches_build_user "$build_workload_username"; then
   add_human_target "$build_workload_username"
fi

unique_principal_labels=("${machine_user_order[@]}" "${human_workload_order[@]}")
echo "Assigning admin roles on ${CDP_ENV_NAME} (unique principals: ${unique_principal_labels[*]})"
echo "Roles: ${ENV_ADMIN_ROLES[*]}"

for machine_user_name in "${machine_user_order[@]}"; do
   assign_machine_user_roles "$machine_user_name" "${machine_user_crns[$machine_user_name]}" || assign_failed=1
done

for workload_username in "${human_workload_order[@]}"; do
   assign_human_user_by_workload "$workload_username" || assign_failed=1
done

cdp environments sync-all-users --environment-names "$CDP_ENV_NAME" >/dev/null 2>&1 || true
cdp environments sync-id-broker-mappings --environment-name "$CDP_ENV_NAME" >/dev/null 2>&1 || true

if [ "$ASSIGN_MACHINE_USER" = "true" ]; then
   machine_user_crn="$(resolve_machine_user_crn "$CDP_MACHINE_USERNAME")"
   if [ -n "$machine_user_crn" ]; then
      if machine_user_has_resource_role "$machine_user_crn" "DFAdmin"; then
         echo "Verified: ${CDP_MACHINE_USERNAME} has DFAdmin on ${CDP_ENV_NAME} (${CDP_ENV_CRN})"
      else
         echo "WARN: ${CDP_MACHINE_USERNAME} does not show DFAdmin on ${CDP_ENV_NAME} after assignment — enable-service may fail until IAM/sync propagates."
      fi
   fi
fi

if [ "$assign_failed" -ne 0 ]; then
   exit 1
fi
