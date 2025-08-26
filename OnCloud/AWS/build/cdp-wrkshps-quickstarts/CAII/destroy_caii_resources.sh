#!/bin/bash

set -e

workshop_name="$1"
env_name="${workshop_name}-cdp-env"
cluster_name="${workshop_name}-compute-cluster"

echo "🔁 Starting cleanup for environment: $env_name"

# --- Delete ML Model Registry ---
delete_model_registry() {
  model_registry_crn=$(cdp ml list-model-registries | jq -r --arg env_name "$env_name" '
    .modelRegistries[] 
    | select(.environmentName == $env_name and .status == "installation:finished") 
    | .crn
  ')
  if [[ -n "$model_registry_crn" ]]; then
    echo "🗑️ Deleting Model Registry: $model_registry_crn"
    cdp ml delete-model-registry --model-registry-crn "$model_registry_crn"
  else
    echo "✅ No Model Registry found"
  fi
}

# --- Delete Compute Cluster ---
delete_compute_cluster() {
  compute_cluster_crn=$(cdp compute list-clusters | jq -r --arg name "$cluster_name" '
    .clusters[] | select(.isDefault == false and .clusterName == $name) | .clusterCrn
  ')
  if [[ -n "$compute_cluster_crn" ]]; then
    echo "🗑️ Deleting Compute Cluster: $compute_cluster_crn"
    cdp compute delete-cluster --cluster-crn "$compute_cluster_crn" --skip-validation
  else
    echo "✅ No Compute Cluster found"
  fi
}

# Run deletion in parallel
delete_model_registry &
pid_model=$!

delete_compute_cluster &
pid_compute=$!

# Wait for both
wait $pid_model
wait $pid_compute

# --- Final Verification Loop ---
echo "🔍 Verifying deletion of all resources..."

while true; do
  still_exists=0

  if cdp ml list-model-registries | jq -e --arg env_name "$env_name" '.modelRegistries[] | select(.environmentName == $env_name)' > /dev/null; then
    echo "⏳ Waiting: Model Registry still exists..."
    still_exists=1
  fi

  if cdp compute list-clusters | jq -e --arg name "$cluster_name" '.clusters[] | select(.isDefault == false and .clusterName == $name)' > /dev/null; then
    echo "⏳ Waiting: Compute Cluster still exists..."
    still_exists=1
  fi

  if [[ "$still_exists" -eq 0 ]]; then
    echo "✅ All resources successfully deleted."
    break
  fi

  sleep 15
done
