#!/bin/bash

set -e

workshop_name=$1
env_name="${workshop_name}-cdp-env"
cluster_name="${workshop_name}-compute-cluster"

echo "🔧 Checking compute cluster: $cluster_name"

existing_cluster_status=$(cdp compute list-clusters | jq -r --arg name "$cluster_name" '
  .clusters[]
  | select(.clusterName == $name)
  | .status
')

# Normalize status to lowercase for case-insensitive matching
existing_status_lower=$(echo "$existing_cluster_status" | tr '[:upper:]' '[:lower:]')

if [[ "$existing_status_lower" == "running" ]]; then
  echo "✅ Compute cluster '$cluster_name' is already RUNNING. Skipping creation."
  exit 0

elif [[ -z "$existing_status_lower" ]]; then
  echo "🚀 Creating compute cluster: $cluster_name"
  cdp compute create-cluster --environment "$env_name" --name "$cluster_name"
elif [[ "$existing_status_lower" == *"failed"* || "$existing_status_lower" == *"error"* || "$existing_status_lower" == *"unhealthy"* ]]; then
  cluster_crn=$(cdp compute list-clusters | jq -r --arg name "$cluster_name" '
    .clusters[]
    | select(.clusterName == $name)
    | .clusterCrn
  ' | head -n 1)
  if [[ -z "$cluster_crn" ]]; then
    echo "❌ Cannot recover compute cluster '$cluster_name': cluster CRN is missing."
    exit 1
  fi
  echo "🔁 Existing compute cluster '$cluster_name' is unhealthy (status: $existing_cluster_status). Recreating only this cluster."
  cdp compute delete-cluster --cluster-crn "$cluster_crn" --skip-validation
  for i in {1..40}; do
    if ! cdp compute list-clusters | jq -e --arg name "$cluster_name" \
      '.clusters[] | select(.clusterName == $name)' >/dev/null; then
      break
    fi
    sleep 15
  done
  if cdp compute list-clusters | jq -e --arg name "$cluster_name" \
    '.clusters[] | select(.clusterName == $name)' >/dev/null; then
    echo "❌ Failed compute cluster was not removed; refusing a duplicate create."
    exit 1
  fi
  cdp compute create-cluster --environment "$env_name" --name "$cluster_name"
else
  echo "ℹ️ Compute cluster '$cluster_name' already exists in status '$existing_cluster_status'. Waiting without submitting another create request."
fi

echo "⏳ Waiting for compute cluster '$cluster_name' to reach RUNNING state..."
for i in {1..60}; do
    current_status=$(cdp compute list-clusters | jq -r --arg name "$cluster_name" '
      .clusters[]
      | select(.clusterName == $name)
      | .status
    ')

    echo "   ➤ Attempt $i: Status = $current_status"

    # Convert to lowercase for comparison
    current_status_lower=$(echo "$current_status" | tr '[:upper:]' '[:lower:]')

    if [[ "$current_status_lower" == "running" ]]; then
      echo "✅ Compute cluster '$cluster_name' is now RUNNING."
      break
    elif [[ "$current_status_lower" == *"failed"* || "$current_status_lower" == *"error"* || "$current_status_lower" == *"unhealthy"* ]]; then
      echo "❌ Compute cluster creation FAILED with status: $current_status"
      exit 1
    fi

    sleep 30
done

if [[ "$current_status_lower" != "running" ]]; then
  echo "❌ Timeout Error: Compute cluster did not reach RUNNING state. Existing resources were preserved."
  exit 1
fi
