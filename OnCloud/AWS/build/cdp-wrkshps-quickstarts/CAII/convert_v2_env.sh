#!/bin/bash

set -euo pipefail

# Sample JSON template file
template_file="convert-v2-env.json"
output_file="updated-$template_file"
tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT

# Example values
env_public_subnets=${1:?Public subnet JSON is required}
workshop_name=${2:?Workshop name is required}
local_ip=${3:?Local IP/CIDR is required}

jq -e 'type == "array" and length > 0' <<<"$env_public_subnets" >/dev/null
local_cidrs=$(jq -cn --arg cidrs "$local_ip" '
  $cidrs
  | split(",")
  | map(gsub("^\\s+|\\s+$"; ""))
  | map(select(length > 0))
')
jq -e 'type == "array" and length > 0' <<<"$local_cidrs" >/dev/null

# Replace values in the template
jq --argjson new_subnets "$env_public_subnets" \
   --arg workshop_name "$workshop_name" \
   --argjson local_cidrs "$local_cidrs" \
   '.computeClusterConfiguration.workerNodeSubnets = $new_subnets
    | .environmentName = ($workshop_name + "-cdp-env")
    | .computeClusterConfiguration.kubeApiAuthorizedIpRanges = $local_cidrs' \
   "$template_file" >"$tmp_file"

mv "$tmp_file" "$output_file"