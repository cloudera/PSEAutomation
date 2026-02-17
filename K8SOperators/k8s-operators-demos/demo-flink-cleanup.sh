#!/bin/bash
BASE_DIR=$(cd $(dirname $0); pwd -L)
source $BASE_DIR/defaults.sh

kubectl get flinkdeployment -A --no-headers --output custom-columns=NAME:.metadata.name,NAME:.metadata.namespace,NAME:.kind | while read name namespace kind; do kubectl -n "$namespace" delete "$kind/$name"; done
kubectl get flinksessionjob -A --no-headers --output custom-columns=NAME:.metadata.name,NAME:.metadata.namespace,NAME:.kind | while read name namespace kind; do kubectl -n "$namespace" delete "$kind/$name"; done
helm uninstall csa-operator --namespace "$CSA_OP_NS"
kubectl -n "$CSA_OP_NS" get pvc --no-headers --output name | xargs kubectl -n "$CSA_OP_NS" delete
kubectl -n "$CSA_OP_NS" get secret --no-headers --output name | egrep -v "token|dockercfg" | xargs kubectl -n "$CSA_OP_NS" delete
kubectl get crds --output jsonpath='{range .items[*]}{"crd/"}{.metadata.name}{"\n"}{end}' | egrep -i "flink" | xargs kubectl delete
kubectl delete namespace "$CSA_OP_NS"
