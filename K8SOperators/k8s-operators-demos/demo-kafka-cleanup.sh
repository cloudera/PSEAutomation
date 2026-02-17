#!/bin/bash
BASE_DIR=$(cd $(dirname $0); pwd -L)
source $BASE_DIR/defaults.sh

for crd in $(kubectl get crds -o name | grep kafka | sed 's#.*/##'); do
  echo "Deleting $crd instances"
  kubectl get "$crd" -A --no-headers --output custom-columns=NAME:.metadata.name,NAME:.metadata.namespace,NAME:.kind | while read name namespace kind; do
    kubectl -n "$namespace" delete "$kind/$name"
  done
done
helm uninstall strimzi-cluster-operator --namespace "$CSM_OP_NS"
kubectl -n "$CSM_OP_NS" get pvc --no-headers --output name | xargs kubectl -n "$CSM_OP_NS" delete
kubectl -n "$CSM_OP_NS" get secret --no-headers --output name | egrep -v "token|dockercfg" | xargs kubectl -n "$CSM_OP_NS" delete
kubectl get crds --output jsonpath='{range .items[*]}{"crd/"}{.metadata.name}{"\n"}{end}' | egrep "strimzi|kafka" | xargs kubectl delete
kubectl delete namespace "$CSM_OP_NS"
