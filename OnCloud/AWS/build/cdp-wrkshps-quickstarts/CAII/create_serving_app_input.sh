#!/bin/bash

set -e

# Input arguments
workshop_name=$1

# Input/output JSON files
template_file="create-serving-app-input.json"
output_file="updated-serving-app-input.json"

# Fetch envCrn and clusterCrn from CDP for a running cluster
read env_crn cluster_crn < <(
  cdp compute list-clusters | jq -r --arg name "${workshop_name}-compute-cluster" '
    .clusters[] 
    | select(.clusterName == $name and .status == "RUNNING") 
    | [.envCrn, .clusterCrn] 
    | @tsv'
)

# Fallback check
if [[ -z "$env_crn" || -z "$cluster_crn" ]]; then
  echo "❌ No running cluster found for '${workshop_name}-compute-cluster'. Exiting."
  exit 1
fi

# Set other values
app_name="${workshop_name}-serving-app"
static_subdomain="${workshop_name}-serving-subdomain"

# Update the JSON using jq
jq --arg app_name "$app_name" \
   --arg env_crn "$env_crn" \
   --arg cluster_crn "$cluster_crn" \
   --arg static_subdomain "$static_subdomain" '
   .appName = $app_name
   | .environmentCrn = $env_crn
   | .clusterCrn = $cluster_crn
   | .staticSubdomain = $static_subdomain
   ' "$template_file" > "$output_file"

echo "✅ Updated $output_file with dynamic values."