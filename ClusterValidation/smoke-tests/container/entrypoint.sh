#!/usr/bin/env bash
set -euo pipefail

# CM_PASS may arrive via env or via a mounted file (chmod 600).
if [[ -z "${CM_PASS:-}" && -r /run/cm_pass ]]; then
  CM_PASS="$(cat /run/cm_pass)"
  export CM_PASS
fi

mkdir -p "${OUTPUT_DIR:-/output}"
exec python3 /app/smoke.py "$@"
