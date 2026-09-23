#!/bin/bash

set -e

# Input: workshop name
workshop_name=$1
env_name="${workshop_name}-cdp-env"

echo "🔧 Checking default compute cluster status for environment: $env_name"

default_cluster_status=$(cdp compute list-clusters | jq -r --arg env_name "$env_name" '
  .clusters[]
  | select(.isDefault == true and .envName == $env_name)
  | .status
')

status_lower=$(echo "$default_cluster_status" | tr '[:upper:]' '[:lower:]')
if [[ -z "$status_lower" ]]; then
  echo "⚙️ Initializing default compute cluster..."
  cdp environments initialize-aws-compute-cluster --cli-input-json file://updated-convert-v2-env.json
elif [[ "$status_lower" == *"failed"* || "$status_lower" == *"error"* || "$status_lower" == *"unhealthy"* ]]; then
  echo "🔁 Existing default compute cluster is unhealthy (status: $default_cluster_status). Requesting reinitialization."
  cdp environments initialize-aws-compute-cluster --cli-input-json file://updated-convert-v2-env.json
else
  echo "ℹ️ Default compute cluster already exists in status '$default_cluster_status'. Waiting without reinitializing."
fi

echo "⏳ Waiting for default compute cluster to reach RUNNING state..."
for i in {1..60}; do
  default_cluster_status=$(cdp compute list-clusters | jq -r --arg env_name "$env_name" '
    .clusters[]
    | select(.isDefault == true and .envName == $env_name)
    | .status
  ')

  echo "   ➤ Attempt $i: Status = $default_cluster_status"

  # Convert to lowercase for case-insensitive matching
  status_lower=$(echo "$default_cluster_status" | tr '[:upper:]' '[:lower:]')

  if [[ "$status_lower" == "running" ]]; then
    echo "✅ Default compute cluster is now RUNNING."
    break
  elif [[ "$status_lower" == *"failed"* || "$status_lower" == *"error"* || "$status_lower" == *"unhealthy"* ]]; then
    echo "❌ Default compute cluster initialization FAILED with status: $default_cluster_status."
    exit 1
  fi
  sleep 60
done

if [[ "$status_lower" != "running" ]]; then
  echo "❌ Timeout Error: Default cluster did not reach RUNNING state after 60 minutes."
  exit 1
fi
