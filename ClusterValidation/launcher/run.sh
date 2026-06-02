#!/usr/bin/env bash
# Host-side runner for the ephemeral-ec2-launcher container.
#
# On success, prints the handoff JSON document to stdout — this is the
# contract any downstream tool (e.g. smoke-tests) consumes. All status
# messages go to stderr so that stdout remains a clean JSON stream.
#
# Parameter precedence (highest → lowest):
#   1. command-line flags     ( --region ap-southeast-1 )
#   2. environment variables  ( AWS_REGION=... )
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

IMAGE_NAME_DEFAULT="ephemeral-ec2-launcher:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_DIR="${SCRIPT_DIR}/container"

log() { echo "$*" >&2; }
die() { echo "ERROR: $*" >&2; exit 2; }

usage() {
  cat >&2 <<'EOF'
Usage: run.sh [OPTIONS]

Target / AWS:
  --env-name NAME          logical env label        (ENV_NAME)
  --region REGION          AWS region               (AWS_REGION)
  --profile NAME           AWS named profile        (AWS_PROFILE)
  --vpc VPC_ID             VPC id                   (VPC_ID)
  --subnet SUBNET_ID       subnet id                (SUBNET_ID)
  --cm-host HOST           CM private IP (used only to discover SGs)  (CM_HOST)
  --instance-type TYPE     EC2 instance type (default: t3.micro)      (INSTANCE_TYPE)

Config / runtime:
  -c, --config FILE        source a KEY=VALUE config file
  --image NAME[:TAG]       container image (default: ephemeral-ec2-launcher:latest)
  --runtime {podman|docker}  force runtime (default: autodetect)
  --build                  build the image before running
  -q, --quiet              no prompts; fail if any required value is unset
  -h, --help               this help

Config file lookup (first match wins, overridable by --config):
  $LAUNCHER_CONFIG
  ./.launcher.env
  ${SCRIPT_DIR}/.launcher.env
  ${XDG_CONFIG_HOME:-$HOME/.config}/ephemeral-ec2-launcher/config
  /etc/ephemeral-ec2-launcher/config

Output:
  On stdout: a single JSON handoff document describing the created resources.
  On stderr: progress logs.
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-name)       ENV_NAME="$2"; shift 2 ;;
    --region)         AWS_REGION="$2"; shift 2 ;;
    --profile)        AWS_PROFILE="$2"; shift 2 ;;
    --vpc)            VPC_ID="$2"; shift 2 ;;
    --subnet)         SUBNET_ID="$2"; shift 2 ;;
    --cm-host)        CM_HOST="$2"; shift 2 ;;
    --instance-type)  INSTANCE_TYPE="$2"; shift 2 ;;
    -c|--config)      CONFIG_FILE="$2"; shift 2 ;;
    --image)          IMAGE_NAME="$2"; shift 2 ;;
    --runtime)        FORCED_RUNTIME="$2"; shift 2 ;;
    --build)          BUILD=1; shift ;;
    -q|--quiet)       QUIET=1; shift ;;
    -h|--help)        usage; exit 0 ;;
    -*)               die "unknown option: $1" ;;
    *)                die "unexpected argument: $1" ;;
  esac
done

# ---------------------------------------------------------------------------
# config file
# ---------------------------------------------------------------------------
if [[ -z "${CONFIG_FILE}" ]]; then
  for candidate in \
      "${LAUNCHER_CONFIG:-}" \
      "./.launcher.env" \
      "${SCRIPT_DIR}/.launcher.env" \
      "${XDG_CONFIG_HOME:-$HOME/.config}/ephemeral-ec2-launcher/config" \
      "/etc/ephemeral-ec2-launcher/config" ; do
    if [[ -n "${candidate}" && -r "${candidate}" ]]; then
      CONFIG_FILE="${candidate}"
      break
    fi
  done
fi

if [[ -n "${CONFIG_FILE}" ]]; then
  [[ -r "${CONFIG_FILE}" ]] || die "config file not readable: ${CONFIG_FILE}"
  KEYS=( ENV_NAME AWS_REGION AWS_PROFILE VPC_ID SUBNET_ID CM_HOST INSTANCE_TYPE )
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

# ---------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------
if [[ "${BUILD}" -eq 1 ]]; then
  log ">> Building ${IMAGE_NAME} with ${RUNTIME}"
  # Redirect build stdout to stderr so our stdout stays pure JSON handoff.
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
  read -r -p "${name}: " val
  [[ -n "${val}" ]] || die "${name} is required"
  export "${name}=${val}"
}

need ENV_NAME
need AWS_REGION
need AWS_PROFILE
need VPC_ID
need SUBNET_ID
need CM_HOST
: "${INSTANCE_TYPE:=t3.micro}"

# ---------------------------------------------------------------------------
# run
# ---------------------------------------------------------------------------
RUN_FLAGS=(
  --rm
  -e "ENV_NAME=${ENV_NAME}"
  -e "AWS_REGION=${AWS_REGION}"
  -e "AWS_DEFAULT_REGION=${AWS_REGION}"
  -e "AWS_PROFILE=${AWS_PROFILE}"
  -e "VPC_ID=${VPC_ID}"
  -e "SUBNET_ID=${SUBNET_ID}"
  -e "CM_HOST=${CM_HOST}"
  -e "INSTANCE_TYPE=${INSTANCE_TYPE}"
  # AWS config: mount under /app (owned by the app user, mode 755 so any UID
  # can traverse) and pass the file paths *explicitly* via AWS_CONFIG_FILE /
  # AWS_SHARED_CREDENTIALS_FILE — bypasses ~/.aws resolution that breaks on
  # macOS Docker when the container runs as a UID with no /etc/passwd entry.
  -v "${HOME}/.aws:/app/.aws:ro"
  -e "AWS_CONFIG_FILE=/app/.aws/config"
  -e "AWS_SHARED_CREDENTIALS_FILE=/app/.aws/credentials"
  -e "HOME=/app"
)

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
log ">> Env:     ${ENV_NAME}   VPC: ${VPC_ID}   Subnet: ${SUBNET_ID}"

# Do NOT allocate a TTY — the handoff JSON must be a clean stdout stream.
exec "${RUNTIME}" run "${RUN_FLAGS[@]}" "${IMAGE_NAME}"
