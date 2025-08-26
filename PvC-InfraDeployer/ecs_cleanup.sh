#!/bin/bash
set -euo pipefail

echo ">>> [1/9] Stopping and removing ECS registry container"
if [[ -x /opt/cloudera/parcels/ECS/docker/docker ]]; then
    /opt/cloudera/parcels/ECS/docker/docker container stop registry || true
    /opt/cloudera/parcels/ECS/docker/docker container rm -v registry || true
    /opt/cloudera/parcels/ECS/docker/docker image rm registry:2 || true
else
    echo "Docker binary not found, skipping registry cleanup."
fi

echo ">>> [2/9] Stopping ECS services via rke2-killall"
if [[ -f /opt/cloudera/parcels/ECS/bin/rke2-killall.sh ]]; then
    cd /opt/cloudera/parcels/ECS/bin
    ./rke2-killall.sh || true
    ./rke2-killall.sh || true
else
    echo "rke2-killall.sh not found, skipping."
fi

echo ">>> [3/9] Uninstall ECS"
if [[ -f /opt/cloudera/parcels/ECS/bin/rke2-uninstall.sh ]]; then
    ./rke2-uninstall.sh || true
else
    echo "rke2-uninstall.sh not found, skipping."
fi

echo ">>> [4/9] Removing ECS related directories"
systemctl daemon-reexec || true
systemctl daemon-reload || true

rm -rfv /ecs/* /var/lib/docker_server/* /etc/docker/certs.d/ /etc/docker/* /var/lib/docker/*
rm -rfv /etc/rancher /var/lib/rancher /var/log/rancher /var/lib/rancher/k3s/server/node-token
rm -rfv /run/k3s /opt/containerd /opt/cni /docker/* /lhdata/* /cdwdata/*
rm -rfv ~/.kube ~/.cache

echo ">>> [5/9] Flushing iptables"
declare -A chains=( [filter]=INPUT:FORWARD:OUTPUT [raw]=PREROUTING:OUTPUT [mangle]=PREROUTING:INPUT:FORWARD:OUTPUT:POSTROUTING [security]=INPUT:FORWARD:OUTPUT [nat]=PREROUTING:INPUT:OUTPUT:POSTROUTING );
for table in "${!chains[@]}"; do
    echo "${chains[$table]}" | tr : $'\n' | while IFS= read -r chain; do
        iptables -t "$table" -P "$chain" ACCEPT || true
    done
    iptables -t "$table" -F || true
    iptables -t "$table" -X || true
done
iptables -F || true

echo ">>> [6/9] Stopping and removing CM agent"
systemctl stop cloudera-scm-agent || true
dnf remove -y cloudera-manager-agent cloudera-manager-daemons || true
rm -rfv /opt/cloudera/cm-agent/
rm -rfv /opt/cloudera/ /var/lib/cloudera-scm-agent

echo ">>> Cleanup complete"
