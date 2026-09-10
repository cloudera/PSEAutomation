#!/bin/bash

workshop_name="$1"
env_name="${workshop_name}-cdp-env"
cluster_name="${workshop_name}-compute-cluster"
MAX_VERIFY_ATTEMPTS=40
VERIFY_SLEEP_SECONDS=15

echo "🔁 Starting cleanup for environment: $env_name"

get_ai_registry_crn() {
  cdp ml list-model-registries 2>/dev/null | jq -r --arg env_name "$env_name" '
    .modelRegistries[]
    | select(.environmentName == $env_name)
    | .crn
  ' | head -n 1
}

get_ai_registry_status() {
  cdp ml list-model-registries 2>/dev/null | jq -r --arg env_name "$env_name" '
    .modelRegistries[]
    | select(.environmentName == $env_name)
    | .status
  ' | head -n 1
}

ai_registry_exists() {
  cdp ml list-model-registries 2>/dev/null | jq -e --arg env_name "$env_name" \
    '.modelRegistries[] | select(.environmentName == $env_name)' > /dev/null
}

# --- Delete AI Registry ---
delete_ai_registry() {
  local ai_registry_crn
  local ai_registry_status

  ai_registry_crn=$(get_ai_registry_crn)
  ai_registry_status=$(get_ai_registry_status)

  if [[ -z "$ai_registry_crn" ]]; then
    echo "✅ No AI Registry found for environment: $env_name"
    return 0
  fi

  echo "🗑️ Deleting AI Registry (status: ${ai_registry_status:-unknown}): $ai_registry_crn"
  if cdp ml delete-model-registry --model-registry-crn "$ai_registry_crn"; then
    echo "✅ AI Registry delete request submitted."
    return 0
  fi

  echo "⚠️ AI Registry delete command failed for CRN: $ai_registry_crn"
  return 1
}

# --- Delete Compute Cluster ---
delete_compute_cluster() {
  local compute_cluster_crn

  compute_cluster_crn=$(cdp compute list-clusters 2>/dev/null | jq -r --arg name "$cluster_name" '
    .clusters[] | select(.isDefault == false and .clusterName == $name) | .clusterCrn
  ' | head -n 1)

  if [[ -n "$compute_cluster_crn" ]]; then
    echo "🗑️ Deleting Compute Cluster: $compute_cluster_crn"
    if cdp compute delete-cluster --cluster-crn "$compute_cluster_crn" --skip-validation; then
      echo "✅ Compute Cluster delete request submitted."
      return 0
    fi
    echo "⚠️ Compute Cluster delete command failed for CRN: $compute_cluster_crn"
    return 1
  fi

  echo "✅ No Compute Cluster found"
  return 0
}

compute_cluster_exists() {
  cdp compute list-clusters 2>/dev/null | jq -e --arg name "$cluster_name" \
    '.clusters[] | select(.isDefault == false and .clusterName == $name)' > /dev/null
}

# Run initial deletion in parallel
delete_ai_registry &
pid_ai_registry=$!

delete_compute_cluster &
pid_compute=$!

wait $pid_ai_registry || true
wait $pid_compute || true

# --- Final Verification Loop ---
echo "🔍 Verifying deletion of all resources..."

for attempt in $(seq 1 "$MAX_VERIFY_ATTEMPTS"); do
  still_exists=0

  if ai_registry_exists; then
    echo "⏳ Attempt ${attempt}/${MAX_VERIFY_ATTEMPTS}: AI Registry still exists (status: $(get_ai_registry_status))..."
    still_exists=1

    # Re-trigger delete if registry is still present after the first attempt
    if [[ "$attempt" -gt 1 && $((attempt % 4)) -eq 0 ]]; then
      echo "🔁 Re-attempting AI Registry deletion..."
      delete_ai_registry || true
    fi
  fi

  if compute_cluster_exists; then
    echo "⏳ Attempt ${attempt}/${MAX_VERIFY_ATTEMPTS}: Compute Cluster still exists..."
    still_exists=1

    if [[ "$attempt" -gt 1 && $((attempt % 4)) -eq 0 ]]; then
      echo "🔁 Re-attempting Compute Cluster deletion..."
      delete_compute_cluster || true
    fi
  fi

  if [[ "$still_exists" -eq 0 ]]; then
    echo "✅ All resources successfully deleted."
    exit 0
  fi

  sleep "$VERIFY_SLEEP_SECONDS"
done

echo "❌ Timeout: Some CAII resources still exist after ${MAX_VERIFY_ATTEMPTS} attempts."
if ai_registry_exists; then
  echo "   - AI Registry still present (status: $(get_ai_registry_status))"
fi
if compute_cluster_exists; then
  echo "   - Compute Cluster still present"
fi
exit 1
