#!/bin/bash

# Sample JSON template file
template_file="convert-v2-env.json"

# Example values
env_public_subnets=$1
workshop_name=$2
local_ip=$3

# Replace values in the template
jq --argjson new_subnets "$env_public_subnets" \
   --arg workshop_name "$workshop_name" \
   --arg local_ip "$local_ip" \
   '.computeClusterConfiguration.workerNodeSubnets = $new_subnets
    | .environmentName = ($workshop_name + "-cdp-env")
    | .computeClusterConfiguration.kubeApiAuthorizedIpRanges = [$local_ip]' \
   "$template_file" > updated-$template_file