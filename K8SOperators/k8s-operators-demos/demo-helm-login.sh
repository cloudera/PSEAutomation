#!/bin/bash
BASE_DIR=$(cd $(dirname $0); pwd -L)
source $BASE_DIR/defaults.sh

helm registry login container.repository.cloudera.com \
  --username "$PAYWALL_USERNAME" \
  --password "$PAYWALL_PASSWORD"
