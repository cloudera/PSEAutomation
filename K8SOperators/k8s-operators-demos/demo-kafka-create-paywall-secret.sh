#!/bin/bash
BASE_DIR=$(cd $(dirname $0); pwd -L)
source $BASE_DIR/defaults.sh

kubectl create secret docker-registry csm-secret \
  --namespace "$CSM_OP_NS" \
  --docker-server container.repository.cloudera.com \
  --docker-username "$PAYWALL_USERNAME" \
  --docker-password "$PAYWALL_PASSWORD"
