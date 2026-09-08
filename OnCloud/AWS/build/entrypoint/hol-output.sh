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

HOL_WIDTH=76

hol_divider() {
   printf '%*s\n' "$HOL_WIDTH" '' | tr ' ' '─'
}

hol_banner() {
   local title="$1"
   local emoji="${2:-🚀}"
   echo ""
   hol_divider
   printf "${HOL_BOLD}${HOL_CYAN}%s  %s${HOL_RESET}\n" "$emoji" "$title"
   hol_divider
   echo ""
}

hol_subsection() {
   local title="$1"
   local emoji="${2:-▶️}"
   echo ""
   printf "${HOL_BOLD}${HOL_BLUE}%s  %s${HOL_RESET}\n" "$emoji" "$title"
   hol_divider
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
   hol_divider
   printf "${HOL_BOLD}${HOL_RED}💥 FATAL${HOL_RESET}\n"
   printf "${HOL_RED}%s${HOL_RESET}\n" "$msg"
   hol_divider
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
   hol_subsection "Deploying $(hol_service_label "$1")" "$(hol_service_emoji "$1")"
}

hol_disable_service() {
   hol_subsection "Disabling $(hol_service_label "$1")" "🗑️"
}

hol_init_service() {
   hol_subsection "Initializing $(hol_service_label "$1")" "$(hol_service_emoji "$1")"
}

hol_service_vars() {
   while [[ $# -ge 2 ]]; do
      hol_kv "$1" "$2"
      shift 2
   done
}

hol_parallel_start() {
   hol_subsection "Running in parallel: $1" "⚡"
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

_hol_box_horizontal() {
   local char="${1:-━}"
   local corner_left="${2:-┏}"
   local corner_right="${3:-┓}"
   printf "${HOL_BOLD}${HOL_CYAN}%s%*s%s${HOL_RESET}\n" \
      "$corner_left" $((HOL_WIDTH - 2)) '' "$corner_right" | tr ' ' "$char"
}

_hol_box_blank() {
   printf "${HOL_BOLD}${HOL_CYAN}┃%*s┃${HOL_RESET}\n" $((HOL_WIDTH - 2)) '' | tr ' ' ' '
}

_hol_box_text() {
   local text="$1"
   local pad=$((HOL_WIDTH - 4 - ${#text}))
   if (( pad < 0 )); then
      text="${text:0:$((HOL_WIDTH - 7))}..."
      pad=0
   fi
   printf "${HOL_BOLD}${HOL_CYAN}┃${HOL_RESET} ${HOL_WHITE}%s${HOL_RESET}%*s${HOL_BOLD}${HOL_CYAN}┃${HOL_RESET}\n" \
      "$text" "$pad" ''
}

hol_startup_banner() {
   echo ""
   _hol_box_horizontal '━' '┏' '┓'
   _hol_box_blank
   _hol_box_text "   ☁  ╭──────────────────────────────────────────────╮"
   _hol_box_text "      │  Cloudera on AWS cloud provisioner           │"
   _hol_box_text "      │  (AutoClouderaDeploy)                        │"
   _hol_box_text "      ╰──────────────────────────────────────────────╯"
   _hol_box_blank
   _hol_box_horizontal '━' '┗' '┛'
   echo ""
}
