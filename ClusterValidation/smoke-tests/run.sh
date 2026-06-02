#!/usr/bin/env bash
# Host-side runner for the cloudera-smoke-tests container.
#
# Reads a launcher handoff JSON from stdin (default) or from --handoff FILE
# and uses it to probe Cloudera Manager and tear the runner down.
#
# The CM password is NEVER accepted on the command line (visible in `ps`).
# Provide it via:  CM_PASS env var | --cm-pass-file PATH | --cm-pass-stdin
#
# Parameter precedence (highest → lowest):
#   1. command-line flags     ( --cluster BaseCluster1 )
#   2. environment variables  ( CLUSTER_NAME=... )
#   3. config file            ( KEY=VALUE, sourced )
#   4. defaults
#   5. interactive prompt (unless --quiet)

set -euo pipefail

# Disable MSYS / Git Bash automatic POSIX→Windows path translation so our
# `-v src:dest` mounts and `-e VAR=/path` env values aren't mangled into
# `C:/Program Files/Git/...` when this script is run under Git Bash on
# Windows. No-op on Linux/macOS and under WSL2.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

IMAGE_NAME_DEFAULT="cloudera-smoke-tests:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_DIR="${SCRIPT_DIR}/container"
OUTPUT_DIR_DEFAULT="${SCRIPT_DIR}/output"

log() { echo "$*" >&2; }
die() { echo "ERROR: $*" >&2; exit 2; }

usage() {
  cat >&2 <<'EOF'
Usage: run.sh [OPTIONS] [-- EXTRA_ARGS_TO_SMOKE_PY...]

Handoff (from ephemeral-ec2-launcher):
  --handoff FILE           path to handoff JSON, or '-' for stdin
                           (default: stdin)

Cloudera Manager:
  --cm-host HOST           CM private IP/DNS        (CM_HOST)
  --cm-port PORT           default 7183             (CM_PORT)
  --cm-user USER           default admin            (CM_USER)
  --cm-pass-file PATH      read CM password from file (chmod 600)
  --cm-pass-stdin          read CM password from stdin
                           [CM_PASS env var also accepted]

Scope / output:
  --cluster NAME           Cloudera cluster name    (CLUSTER_NAME)

Data Services (optional; cluster names to probe for ECS/PvC):
  --data-services-cluster NAMES   comma-separated cluster names
                                    (DATA_SERVICES_CLUSTER)

  --services LIST          comma list or 'all'      (SERVICES_TO_TEST)
  --formats LIST           nagios,prom,json,html    (OUTPUT_FORMATS)
  --output-dir PATH        host directory for results (default: ./output)

AWS session (required; the container reuses your SSO cache):
  --region REGION          AWS region               (AWS_REGION)
  --profile NAME           AWS named profile        (AWS_PROFILE)

Cluster SSH (optional; enables df -hT per-host disk diagnostics):
  --ssh-key-file PATH      private key for cluster hosts (chmod 600)
                                                    (SSH_KEY_FILE)
  --ssh-user USER          ssh login user, default ec2-user
                                                    (SSH_USER)

Config / runtime:
  -c, --config FILE        source a KEY=VALUE config file
  --image NAME[:TAG]       container image (default: cloudera-smoke-tests:latest)
  --runtime {podman|docker}  force runtime (default: autodetect)
  --build                  build the image before running
  -q, --quiet              no prompts; fail if any required value is unset
  -h, --help               this help

Config file lookup (first match wins, overridable by --config):
  $SMOKE_CONFIG
  ./.smoke.env
  ${SCRIPT_DIR}/.smoke.env
  ${XDG_CONFIG_HOME:-$HOME/.config}/cloudera-smoke-tests/config
  /etc/cloudera-smoke-tests/config

Exit codes: Nagios convention — 0 OK, 1 WARN, 2 CRIT, 3 UNKNOWN.
EOF
}

# ---------------------------------------------------------------------------
# arg parsing
# ---------------------------------------------------------------------------
BUILD=0
QUIET=0
CONFIG_FILE=""
IMAGE_NAME=""
FORCED_RUNTIME=""
CM_PASS_FILE=""
CM_PASS_STDIN=0
OUTPUT_DIR=""
HANDOFF_FILE="-"
SSH_KEY_FILE_CLI=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --handoff)        HANDOFF_FILE="$2"; shift 2 ;;
    --region)         AWS_REGION="$2"; shift 2 ;;
    --profile)        AWS_PROFILE="$2"; shift 2 ;;
    --cm-host)        CM_HOST="$2"; shift 2 ;;
    --cm-port)        CM_PORT="$2"; shift 2 ;;
    --cm-user)        CM_USER="$2"; shift 2 ;;
    --cm-pass-file)   CM_PASS_FILE="$2"; shift 2 ;;
    --cm-pass-stdin)  CM_PASS_STDIN=1; shift ;;
    --cluster)        CLUSTER_NAME="$2"; shift 2 ;;
    --data-services-cluster)  DATA_SERVICES_CLUSTER="$2"; shift 2 ;;
    --services)       SERVICES_TO_TEST="$2"; shift 2 ;;
    --formats)        OUTPUT_FORMATS="$2"; shift 2 ;;
    --output-dir)     OUTPUT_DIR="$2"; shift 2 ;;
    --ssh-key-file)   SSH_KEY_FILE_CLI="$2"; shift 2 ;;
    --ssh-user)       SSH_USER="$2"; shift 2 ;;
    -c|--config)      CONFIG_FILE="$2"; shift 2 ;;
    --image)          IMAGE_NAME="$2"; shift 2 ;;
    --runtime)        FORCED_RUNTIME="$2"; shift 2 ;;
    --build)          BUILD=1; shift ;;
    -q|--quiet)       QUIET=1; shift ;;
    -h|--help)        usage; exit 0 ;;
    --cm-pass=*|--cm-password=*)
                      die "passwords must not be on the command line; use --cm-pass-file, --cm-pass-stdin, or the CM_PASS env var" ;;
    --)               shift; EXTRA_ARGS=("$@"); break ;;
    -*)               die "unknown option: $1" ;;
    *)                EXTRA_ARGS+=("$1"); shift ;;
  esac
done

# ---------------------------------------------------------------------------
# config file
# ---------------------------------------------------------------------------
if [[ -z "${CONFIG_FILE}" ]]; then
  for candidate in \
      "${SMOKE_CONFIG:-}" \
      "./.smoke.env" \
      "${SCRIPT_DIR}/.smoke.env" \
      "${XDG_CONFIG_HOME:-$HOME/.config}/cloudera-smoke-tests/config" \
      "/etc/cloudera-smoke-tests/config" ; do
    if [[ -n "${candidate}" && -r "${candidate}" ]]; then
      CONFIG_FILE="${candidate}"
      break
    fi
  done
fi

if [[ -n "${CONFIG_FILE}" ]]; then
  [[ -r "${CONFIG_FILE}" ]] || die "config file not readable: ${CONFIG_FILE}"
  # Refuse world/group-readable config files that contain CM_PASS.
  if grep -qE '^[[:space:]]*CM_PASS[[:space:]]*=' "${CONFIG_FILE}"; then
    perms=$(stat -c '%a' "${CONFIG_FILE}" 2>/dev/null || stat -f '%Lp' "${CONFIG_FILE}")
    if [[ "${perms}" != "600" && "${perms}" != "400" ]]; then
      die "config file ${CONFIG_FILE} contains CM_PASS but has mode ${perms}; chmod 600 first"
    fi
  fi
  KEYS=( AWS_REGION AWS_PROFILE CM_HOST CM_PORT CM_USER CM_PASS \
         CLUSTER_NAME DATA_SERVICES_CLUSTER SERVICES_TO_TEST OUTPUT_FORMATS \
         SSH_KEY_FILE SSH_USER )
  declare -A _PRE
  for k in "${KEYS[@]}"; do _PRE[$k]="${!k-}"; done
  set -a
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
  set +a
  for k in "${KEYS[@]}"; do
    if [[ -n "${_PRE[$k]:-}" ]]; then export "$k=${_PRE[$k]}"; fi
  done
  unset _PRE KEYS
  log ">> Loaded config from ${CONFIG_FILE}"
  log ">> DATA_SERVICES_CLUSTER=${DATA_SERVICES_CLUSTER:-<default>}"
fi

# ---------------------------------------------------------------------------
# password sourcing
# ---------------------------------------------------------------------------
if [[ -z "${CM_PASS:-}" && -n "${CM_PASS_FILE}" ]]; then
  [[ -r "${CM_PASS_FILE}" ]] || die "cannot read password file: ${CM_PASS_FILE}"
  perms=$(stat -c '%a' "${CM_PASS_FILE}" 2>/dev/null || stat -f '%Lp' "${CM_PASS_FILE}")
  if [[ "${perms}" != "600" && "${perms}" != "400" ]]; then
    log "WARNING: ${CM_PASS_FILE} mode is ${perms} (expected 600/400)"
  fi
  CM_PASS="$(<"${CM_PASS_FILE}")"
  CM_PASS="${CM_PASS%$'\n'}"
fi
if [[ "${CM_PASS_STDIN}" -eq 1 && "${HANDOFF_FILE}" == "-" ]]; then
  die "--cm-pass-stdin and --handoff - both read from stdin; pick one"
fi
if [[ -z "${CM_PASS:-}" && "${CM_PASS_STDIN}" -eq 1 ]]; then
  IFS= read -rs CM_PASS
  echo >&2
fi

# ---------------------------------------------------------------------------
# runtime detection
# ---------------------------------------------------------------------------
RUNTIME="${FORCED_RUNTIME:-${CONTAINER_RUNTIME:-}}"
if [[ -z "${RUNTIME}" ]]; then
  if command -v podman >/dev/null 2>&1; then RUNTIME=podman
  elif command -v docker >/dev/null 2>&1; then RUNTIME=docker
  else die "neither podman nor docker found on PATH"
  fi
fi
command -v "${RUNTIME}" >/dev/null 2>&1 || die "runtime '${RUNTIME}' not on PATH"

: "${IMAGE_NAME:=${IMAGE_NAME_DEFAULT}}"
: "${OUTPUT_DIR:=${OUTPUT_DIR_DEFAULT}}"

# ---------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------
if [[ "${BUILD}" -eq 1 ]]; then
  log ">> Building ${IMAGE_NAME} with ${RUNTIME}"
  # Build noise goes to stderr; stdout is reserved for the Nagios one-liner.
  "${RUNTIME}" build \
    --build-arg IMAGE_CREATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --build-arg IMAGE_REVISION="$(git -C "${SCRIPT_DIR}" rev-parse --short HEAD 2>/dev/null || echo local)" \
    -t "${IMAGE_NAME}" \
    "${CONTAINER_DIR}" >&2
fi

if ! "${RUNTIME}" image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  die "image '${IMAGE_NAME}' not found locally. Rerun with --build to build it (see --help)."
fi

# ---------------------------------------------------------------------------
# fill remaining required values
# ---------------------------------------------------------------------------
need() {
  local name="$1" def="${2:-}"
  if [[ -n "${!name:-}" ]]; then return 0; fi
  if [[ -n "${def}" ]]; then export "${name}=${def}"; return 0; fi
  if [[ "${QUIET}" -eq 1 ]]; then die "required parameter ${name} not set (and --quiet given)"; fi
  local val
  read -r -p "${name}: " val </dev/tty
  [[ -n "${val}" ]] || die "${name} is required"
  export "${name}=${val}"
}
need_secret() {
  local name="$1" val
  if [[ -n "${!name:-}" ]]; then return 0; fi
  if [[ "${QUIET}" -eq 1 ]]; then die "${name} not set (and --quiet given)"; fi
  read -r -s -p "${name}: " val </dev/tty; echo >&2
  [[ -n "${val}" ]] || die "${name} is required"
  export "${name}=${val}"
}

need AWS_REGION
need AWS_PROFILE
need CM_HOST
need CM_PORT "7183"
need CM_USER "admin"
need_secret CM_PASS
need CLUSTER_NAME
need SERVICES_TO_TEST "all"
: "${OUTPUT_FORMATS:=nagios,prom,json,html}"
: "${SSH_USER:=ec2-user}"

# CLI flag wins over env / config for the SSH key path.
if [[ -n "${SSH_KEY_FILE_CLI}" ]]; then SSH_KEY_FILE="${SSH_KEY_FILE_CLI}"; fi

# Resolve to an absolute path and validate. The key is optional: if not set,
# the per-host disk-utilization section will SKIP with a hint.
SSH_KEY_ABS=""
if [[ -n "${SSH_KEY_FILE:-}" ]]; then
  [[ -r "${SSH_KEY_FILE}" ]] || die "SSH key not readable: ${SSH_KEY_FILE}"
  SSH_KEY_ABS="$(readlink -f "${SSH_KEY_FILE}")"
  perms=$(stat -c '%a' "${SSH_KEY_ABS}" 2>/dev/null || stat -f '%Lp' "${SSH_KEY_ABS}")
  if [[ "${perms}" != "600" && "${perms}" != "400" ]]; then
    log "WARNING: ${SSH_KEY_ABS} mode is ${perms} (expected 600/400)"
  fi
fi

mkdir -p "${OUTPUT_DIR}" || die "cannot create ${OUTPUT_DIR}"

# ---------------------------------------------------------------------------
# stage the handoff JSON
# ---------------------------------------------------------------------------
# If --handoff is '-', capture stdin to a temp file so we can still pipe it
# into the container cleanly (stdin is also used by --cm-pass-stdin on
# interactive paths, but those are mutually exclusive here).
HANDOFF_STAGE=""
if [[ "${HANDOFF_FILE}" == "-" ]]; then
  # Refuse to read from a TTY — that would hang silently waiting for EOF.
  if [[ -t 0 ]]; then
    die "no handoff provided. Pipe launcher output in (./launcher/run.sh | ./smoke-tests/run.sh) or pass --handoff FILE."
  fi
  HANDOFF_STAGE="$(mktemp -t smoke-handoff.XXXXXX)"
  trap 'rm -f "${HANDOFF_STAGE}" "${ENV_FILE:-}"' EXIT
  cat > "${HANDOFF_STAGE}"
  if [[ ! -s "${HANDOFF_STAGE}" ]]; then
    die "handoff on stdin was empty. Did the launcher succeed?"
  fi
  HANDOFF_ABS="${HANDOFF_STAGE}"
else
  [[ -r "${HANDOFF_FILE}" ]] || die "handoff file not readable: ${HANDOFF_FILE}"
  [[ -s "${HANDOFF_FILE}" ]] || die "handoff file is empty: ${HANDOFF_FILE}"
  HANDOFF_ABS="$(readlink -f "${HANDOFF_FILE}")"
fi

# Pass the password via --env-file (chmod 600) so it doesn't leak to `ps`.
ENV_FILE="$(mktemp -t smoke-env.XXXXXX)"
chmod 600 "${ENV_FILE}"
if [[ -z "${HANDOFF_STAGE}" ]]; then
  trap 'rm -f "${ENV_FILE}"' EXIT
fi
printf 'CM_PASS=%s\n' "${CM_PASS}" > "${ENV_FILE}"

# ---------------------------------------------------------------------------
# assemble runtime flags
# ---------------------------------------------------------------------------
RUN_FLAGS=(
  --rm
  -i
  --env-file "${ENV_FILE}"
  -e "AWS_REGION=${AWS_REGION}"
  -e "AWS_DEFAULT_REGION=${AWS_REGION}"
  -e "AWS_PROFILE=${AWS_PROFILE}"
  -e "CM_HOST=${CM_HOST}"
  -e "CM_PORT=${CM_PORT}"
  -e "CM_USER=${CM_USER}"
  -e "CLUSTER_NAME=${CLUSTER_NAME}"
  -e "DATA_SERVICES_CLUSTER=${DATA_SERVICES_CLUSTER:-}"
  -e "SERVICES_TO_TEST=${SERVICES_TO_TEST}"
  -e "OUTPUT_FORMATS=${OUTPUT_FORMATS}"
  -e "SSH_USER=${SSH_USER}"
  # AWS config: mount under /app (owned by the app user, mode 755 so any UID
  # can traverse) and pass the file paths *explicitly* via AWS_CONFIG_FILE /
  # AWS_SHARED_CREDENTIALS_FILE — bypasses ~/.aws resolution that breaks on
  # macOS Docker when the container runs as a UID with no /etc/passwd entry.
  -v "${HOME}/.aws:/app/.aws:ro"
  -e "AWS_CONFIG_FILE=/app/.aws/config"
  -e "AWS_SHARED_CREDENTIALS_FILE=/app/.aws/credentials"
  -e "HOME=/app"
  -v "${OUTPUT_DIR}:/output:rw"
)
if [[ -n "${SSH_KEY_ABS}" ]]; then
  RUN_FLAGS+=( -v "${SSH_KEY_ABS}:/run/ssh_key:ro" )
fi

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
if [[ "${RUNTIME}" == "podman" ]]; then
  if podman run --rm --userns=keep-id:uid=10001,gid=10001 alpine true >/dev/null 2>&1; then
    RUN_FLAGS+=( --userns=keep-id:uid=10001,gid=10001 )
  else
    log "NOTE: podman < 4.3 detected; falling back to --user ${HOST_UID}:${HOST_GID}"
    RUN_FLAGS+=( --user "${HOST_UID}:${HOST_GID}" )
  fi
else
  RUN_FLAGS+=( --user "${HOST_UID}:${HOST_GID}" )
fi

log ">> Runtime: ${RUNTIME}"
log ">> Image:   ${IMAGE_NAME}"
log ">> Output:  ${OUTPUT_DIR}"
log ">> Cluster: ${CLUSTER_NAME}   CM: ${CM_HOST}:${CM_PORT}"
if [[ -n "${SSH_KEY_ABS}" ]]; then
  log ">> SSH:     ${SSH_USER}@<host> using ${SSH_KEY_ABS} (df -hT diagnostics)"
else
  log ">> SSH:     no key configured — Disk Utilization will SKIP (set SSH_KEY_FILE in .smoke.env)"
fi

# Feed the handoff into the container's stdin so smoke.py reads it.
set +e
"${RUNTIME}" run "${RUN_FLAGS[@]}" "${IMAGE_NAME}" "${EXTRA_ARGS[@]}" < "${HANDOFF_ABS}"
RC=$?
set -e

case "${RC}" in
  0) log "Exit: 0 (OK)" ;;
  1) log "Exit: 1 (WARNING)" ;;
  2) log "Exit: 2 (CRITICAL)" ;;
  3) log "Exit: 3 (UNKNOWN)" ;;
  *) log "Exit: ${RC}" ;;
esac
exit "${RC}"
