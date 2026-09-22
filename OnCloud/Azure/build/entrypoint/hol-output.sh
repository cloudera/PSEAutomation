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

HOL_LOG_TAILER_PIDS=()

hol_service_log_file_by_tag() {
   local service_tag="$1"
   local workshop="${workshop_name:-hol}"
   local log_dir="/userconfig/.${workshop}/logs"
   mkdir -p "$log_dir"
   echo "${log_dir}/${service_tag}.log"
}

hol_ansible_log_file() {
   hol_service_log_file_by_tag "${HOL_SERVICE_TAG:-ansible}"
}

hol_ansible_log_format_script() {
   local d script
   for d in /usr/local/bin "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; do
      script="${d}/hol-ansible-log-format.py"
      if [[ -f "$script" ]]; then
         echo "$script"
         return 0
      fi
   done
   return 1
}

hol_print_tagged_ansible_log_line() {
   local tag="$1"
   local line="$2"
   local script
   # Prefix only; compact skip lines when the formatter is available.
   if [[ "$line" =~ ^skipping: ]]; then
      script="$(hol_ansible_log_format_script)" || {
         echo "[${tag}] ${line}"
         return 0
      }
      python3 "$script" format-tagged-line "$tag" "$line"
      return 0
   fi
   echo "[${tag}] ${line}"
}

hol_fixup_cloudera_cloud_python() {
   if [[ -x /usr/local/bin/hol-patch-python-deps.sh ]]; then
      /usr/local/bin/hol-patch-python-deps.sh || true
      return
   fi
   local collection_root f
   for collection_root in \
      /root/.ansible/collections/ansible_collections/cloudera/cloud \
      "${HOME}/.ansible/collections/ansible_collections/cloudera/cloud"; do
      f="${collection_root}/plugins/module_utils/cdp_service.py"
      [[ -f "$f" ]] || continue
      if grep -q 'SEMVER = re.compile("(\\d+' "$f" 2>/dev/null; then
         sed -i 's/SEMVER = re.compile("(\\d+/SEMVER = re.compile(r"(\\d+/' "$f"
         hol_info "Patched cloudera.cloud SEMVER regex in ${f}"
      fi
      f="${collection_root}/plugins/module_utils/cdp_de.py"
      if [[ -f "$f" ]] && grep -q 'Must match regex:.*\[a-zA-Z0-9\\-\.\]' "$f" 2>/dev/null; then
         python3 - "$f" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text2, n = re.subn(
    r'f"Invalid service name: \{name\}\. Must match regex: \^\[a-zA-Z\]\[a-zA-Z0-9\\-\\.\]\+\[a-zA-Z0-9\]\$"',
    r'f"Invalid service name: {name}. Must match regex: ^[a-zA-Z][a-zA-Z0-9\\\\-\\\\.]+[a-zA-Z0-9]$"',
    text,
    count=1,
)
if n:
    path.write_text(text2, encoding="utf-8")
    print(f"hol-patch: fixed CDE name regex f-string in {path}")
PY
      fi
   done
   hol_warn "hol-patch-python-deps.sh missing — cdpcli/cloudera.cloud may emit SyntaxWarning on Python 3.12+"
}

hol_start_service_log_tailer() {
   local tag="$1"
   local log_file
   log_file="$(hol_service_log_file_by_tag "$tag")"
   touch "$log_file"

   (
      tail -n 0 -F "$log_file" 2>/dev/null | while IFS= read -r line || [[ -n "$line" ]]; do
         hol_print_tagged_ansible_log_line "$tag" "$line"
      done
   ) &
   HOL_LOG_TAILER_PIDS+=($!)
}

hol_stop_service_log_tailers() {
   local pid
   for pid in "${HOL_LOG_TAILER_PIDS[@]}"; do
      kill "$pid" 2>/dev/null || true
   done
   HOL_LOG_TAILER_PIDS=()
   sleep 0.2
}

# Wait for every background data-service job (continue-on-failure). Nameref arrays:
# pids[i] aligns with service_tokens[i]. Sets HOL_FAILED_DATA_SERVICES to short names (CDW, CDE, …).
hol_wait_parallel_data_services() {
   local -n _hol_pids=$1
   local -n _hol_tokens=$2
   local failed_short=() joined workshop
   local i pid

   HOL_FAILED_DATA_SERVICES=""
   workshop="${workshop_name:-hol}"

   for i in "${!_hol_pids[@]}"; do
      pid=${_hol_pids[$i]}
      if ! wait "$pid"; then
         if [[ -n "${_hol_tokens[$i]:-}" ]]; then
            failed_short+=("$(hol_service_short "${_hol_tokens[$i]}")")
         else
            failed_short+=("unknown")
         fi
      fi
   done

   if ((${#failed_short[@]} == 0)); then
      return 0
   fi

   joined=$(IFS=', '; echo "${failed_short[*]}")
   HOL_FAILED_DATA_SERVICES="$joined"
   hol_warn "Data service playbook(s) failed: ${joined} — see /userconfig/.${workshop}/logs/*.log"
   return 1
}

# Ansible writes to per-service log files; tailers stream to the console.
# Enable default-callback ANSI when the console is a TTY or HOL_ANSIBLE_COLOR is set.
hol_ansible_force_color() {
   case "${HOL_ANSIBLE_COLOR:-}" in
      1|true|TRUE|yes|YES|on|ON) echo 1; return 0 ;;
   esac
   if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
      echo 1
      return 0
   fi
   echo 0
}

_hol_strip_ansi_from_stream() {
   sed $'s/\x1b\\[[0-9;]*[a-zA-Z]//g'
}

hol_run_ansible_playbook() {
   local log_file tag rc stream_cmd force_color
   tag="${HOL_SERVICE_TAG:-ansible}"
   log_file="$(hol_ansible_log_file)"
   : >"$log_file"

   hol_fixup_cloudera_cloud_python

   hol_info "${tag} playbook log: ${log_file}"

   if command -v stdbuf >/dev/null 2>&1; then
      stream_cmd=(stdbuf -oL -eL)
   else
      stream_cmd=()
   fi

   force_color="$(hol_ansible_force_color)"

   "${stream_cmd[@]}" env \
      HOL_SERVICE_TAG= \
      ANSIBLE_STDOUT_CALLBACK=default \
      ANSIBLE_FORCE_COLOR="${force_color}" \
      PYTHONUNBUFFERED=1 \
      PYTHONWARNINGS="${HOL_ANSIBLE_PYTHONWARNINGS:-ignore::SyntaxWarning}" \
      ansible-playbook "$@" >>"$log_file" 2>&1
   rc=$?

   if (( rc != 0 )); then
      hol_warn "${tag} playbook failed — full log: ${log_file}"
      if [[ -f "$log_file" ]]; then
         _hol_strip_ansi_from_stream <"$log_file" \
            | grep -E '(^fatal: |fatal: \[|UNREACHABLE!|failed=[1-9]|unreachable=[1-9]|^PLAY RECAP)' \
            | tail -40 >&2 || true
      fi
      return "$rc"
   fi
   return 0
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
