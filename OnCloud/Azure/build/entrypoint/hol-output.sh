#!/bin/bash
# Shared colorful / emoji logging helpers for HoL automation scripts.

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
   HOL_RESET='\033[0m'
   HOL_BOLD='\033[1m'
   HOL_DIM='\033[2m'
   HOL_RED='\033[31m'
   HOL_GREEN='\033[32m'
   HOL_YELLOW='\033[33m'
   HOL_BLUE='\033[34m'
   HOL_MAGENTA='\033[35m'
   HOL_CYAN='\033[36m'
   HOL_WHITE='\033[37m'
else
   HOL_RESET='' HOL_BOLD='' HOL_DIM='' HOL_RED='' HOL_GREEN='' HOL_YELLOW=''
   HOL_BLUE='' HOL_MAGENTA='' HOL_CYAN='' HOL_WHITE=''
fi

# Section headers: left-aligned title with full-width rule lines.
HOL_SECTION_WIDTH=86
HOL_SECTION_INDENT=0
HOL_RULE_CHAR='-'

_hol_rule_line() {
   local width="${HOL_SECTION_WIDTH}"
   printf '%*s' "$width" '' | tr ' ' "${HOL_RULE_CHAR}"
}

hol_section() {
   local title="$1"
   local width="${HOL_SECTION_WIDTH}"
   local rule

   rule="$(_hol_rule_line)"

   if [[ -z "$title" ]]; then
      printf '\n%s\n' "$rule"
      return
   fi

   if (( ${#title} > width - 4 )); then
      title="${title:0:$((width - 7))}..."
   fi

   printf '\n%s\n' "$rule"
   printf '%s\n' "$title"
   printf '%s\n' "$rule"
}

hol_divider() {
   hol_section ""
}

hol_banner() {
   local title="$1"
   local emoji="${2:-🚀}"
   hol_section "${emoji}  ${title}"
}

hol_subsection() {
   local title="$1"
   local emoji="${2:-▶️}"
   hol_section "${emoji}  ${title}"
}

hol_milestone() {
   local title="$1"
   local emoji="${2:-✅}"
   hol_section "${emoji}  ${title}"
}

hol_step() {
   printf "${HOL_CYAN}⏳ %s${HOL_RESET}\n" "$1"
}

hol_ok() {
   printf "${HOL_GREEN}✅ %s${HOL_RESET}\n" "$1"
}

hol_warn() {
   printf "${HOL_YELLOW}⚠️  %s${HOL_RESET}\n" "$1"
}

hol_info() {
   printf "${HOL_DIM}ℹ️  %s${HOL_RESET}\n" "$1"
}

hol_skip() {
   printf "${HOL_YELLOW}⏭️  %s${HOL_RESET}\n" "$1"
}

hol_kv() {
   printf "   ${HOL_DIM}•${HOL_RESET} ${HOL_WHITE}%s:${HOL_RESET} %s\n" "$1" "$2"
}

hol_fail() {
   local msg="$1"
   local code="${2:-1}"
   echo ""
   hol_section "💥  FATAL"
   printf "${HOL_RED}%s${HOL_RESET}\n" "$msg"
   hol_section ""
   echo ""
   exit "$code"
}

hol_check_info() {
   hol_info "$1"
}

hol_check_pass() {
   hol_ok "$1"
}

hol_quota_fail() {
   hol_fail "$1"
}

hol_service_short() {
   case "$1" in
   cdw) echo "CDW" ;;
   cde) echo "CDE" ;;
   cai) echo "CAI" ;;
   cdf) echo "CDF" ;;
   *) echo "$1" ;;
   esac
}

hol_service_emoji() {
   case "$1" in
   cdw) echo "🏢" ;;
   cde) echo "⚡" ;;
   cai) echo "🤖" ;;
   cdf) echo "🌊" ;;
   *) echo "📦" ;;
   esac
}

hol_service_label() {
   case "$1" in
   cdw) echo "CDW (Cloudera Data Warehouse)" ;;
   cde) echo "CDE (Cloudera Data Engineering)" ;;
   cai) echo "CAI (Cloudera AI)" ;;
   cdf) echo "CDF (Cloudera Data Flow)" ;;
   *) echo "$1" ;;
   esac
}

hol_deploy_service() {
   hol_section "$(hol_service_emoji "$1")  Deploying $(hol_service_short "$1")"
}

hol_disable_service() {
   hol_section "🗑️  Disabling $(hol_service_short "$1")"
}

hol_init_service() {
   hol_section "$(hol_service_emoji "$1")  Initializing $(hol_service_short "$1")"
}

hol_service_vars() {
   while [[ $# -ge 2 ]]; do
      hol_kv "$1" "$2"
      shift 2
   done
}

hol_parallel_start() {
   hol_section "⚡  Deploying data services in parallel"
}

hol_ansible_log_file() {
   local service_tag="${HOL_SERVICE_TAG:-ansible}"
   local workshop="${workshop_name:-hol}"
   local log_dir="/userconfig/.${workshop}/logs"
   mkdir -p "$log_dir"
   echo "${log_dir}/${service_tag}.log"
}

hol_run_ansible_playbook() {
   local log_file
   log_file="$(hol_ansible_log_file)"
   : >"$log_file"

   if ansible-playbook "$@" >>"$log_file" 2>&1; then
      return 0
   fi

   while IFS= read -r line; do
      printf '[%s] %s\n' "${HOL_SERVICE_TAG:-?}" "$line"
   done <"$log_file"
   hol_warn "Full ${HOL_SERVICE_TAG:-ansible} log: ${log_file}"
   return 1
}

hol_role_ok() {
   hol_ok "Role '${1}' assigned to group '${2}'"
}

hol_role_skip() {
   hol_skip "Role '${1}' already assigned to group '${2}'"
}

hol_role_error() {
   hol_warn "Failed to assign role '${1}' to group '${2}'"
}

hol_provision_failed() {
   local workshop="${1:-workshop}"
   hol_fail "Infrastructure provisioning for '${workshop}' failed. Review the logs above and try again."
}

hol_destroy_failed() {
   local workshop="${1:-workshop}"
   hol_fail "Infrastructure destroy for '${workshop}' did not complete. Review Terraform errors above, then retry destroy or clean up remaining Azure resources manually."
}

_hol_startup_hbar() {
   local width="$1"
   local char="${2:--}"
   printf '%*s' "$width" '' | tr ' ' "$char"
}

_hol_startup_outer_line() {
   local left_corner="$1"
   local right_corner="$2"
   local bar_char="${3:--}"
   local bar
   bar="$(_hol_startup_hbar $((HOL_SECTION_WIDTH - 2)) "$bar_char")"
   printf '%s%s%s\n' "$left_corner" "$bar" "$right_corner"
}

_hol_startup_outer_blank() {
   local inner=$((HOL_SECTION_WIDTH - 2))
   printf '|%*s|\n' "$inner" ''
}

_hol_startup_outer_content() {
   local content="$1"
   local inner=$((HOL_SECTION_WIDTH - 2))
   local tlen=${#content}
   local pad left right

   if (( tlen > inner )); then
      content="${content:0:$((inner - 3))}..."
      tlen=${#content}
   fi

   pad=$((inner - tlen))
   left=$((pad / 2))
   right=$((pad - left))
   printf '|%*s%s%*s|\n' "$left" '' "$content" "$right" ''
}

_hol_startup_inner_text() {
   local text="$1"
   local inner_width="$2"
   local tlen=${#text}
   local pad=$((inner_width - tlen - 2))
   local left=$((pad / 2))
   local right=$((pad - left))
   printf '| %*s%s%*s |' "$left" '' "$text" "$right" ''
}

hol_startup_banner() {
   local inner_width=46
   local hline
   local title="Cloudera on Azure cloud provisioner"
   local subtitle="(AutoClouderaDeploy)"

   hline="$(_hol_startup_hbar "$inner_width" '-')"

   echo ""
   _hol_startup_outer_line '+' '+'
   _hol_startup_outer_blank
   _hol_startup_outer_content "  +${hline}+"
   _hol_startup_outer_content "  $(_hol_startup_inner_text "$title" "$inner_width")"
   _hol_startup_outer_content "  $(_hol_startup_inner_text "$subtitle" "$inner_width")"
   _hol_startup_outer_content "  +${hline}+"
   _hol_startup_outer_blank
   _hol_startup_outer_line '+' '+'
   echo ""
}
