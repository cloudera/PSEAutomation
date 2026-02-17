#!/bin/bash
BASE_DIR=$(cd $(dirname $0); pwd -L)
source $BASE_DIR/defaults.sh

helm install strimzi-cluster-operator \
  --namespace "$CSM_OP_NS" \
  --set 'image.imagePullSecrets[0].name=csm-secret' \
  --set watchAnyNamespace=true \
  --set-file clouderaLicense.fileContent="$LICENSE_FILE" \
  oci://container.repository.cloudera.com/cloudera-helm/csm-operator/strimzi-kafka-operator \
  --version "$CSM_OP_VERSION"

