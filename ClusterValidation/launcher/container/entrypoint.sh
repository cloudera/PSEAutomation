#!/usr/bin/env bash
set -euo pipefail

# The launcher emits its handoff JSON on stdout and logs on stderr. Do NOT
# write anything else to stdout from this script.
exec python3 /app/launcher.py "$@"
