# On each host in the cluster:
/opt/cloudera/parcels/ECS/docker/docker container stop registry
/opt/cloudera/parcels/ECS/docker/docker container rm -v registry
/opt/cloudera/parcels/ECS/docker/docker image rm registry:2

# Stop the ECS cluster in Cloudera Manager
# On each host:
cd /opt/cloudera/parcels/ECS/bin
./rke2-killall.sh # usually 2 times is sufficient

# Use umount to unmount all NFS disks.
# umount /docker /lhdata /cdwdata  #not needed in our case
./rke2-uninstall.sh
rm -rvf /ecs/*                             # assumes the default defaultDataPath and lsoDataPath
rm -rvf /var/lib/docker_server/*           # deletes the auth and certs
rm -rvf /etc/docker/certs.d/ /etc/docker/* # delete the ca.crt
rm -rvf /var/lib/docker/*
rm -rvf /etc/rancher /var/lib/rancher /var/log/rancher /var/lib/rancher/k3s/server/node-token
rm -rvf /run/k3s /opt/containerd /opt/cni
rm -rvf /docker/* /lhdata/* /cdwdata/*
rm -rvf ~/.kube ~/.cache
rm -rvf /opt/cloudera/parcels/* /opt/cloudera/parcel-cache/*
rm -rvf /var/lib/docker/* /var/lib/docker_server/*systemctl daemon-reload

# Delete the ECS cluster in Cloudera Manager.
# In Cloudera Manager, navigate to CDP Private Cloud Data Services and click . Click Uninstall.
# The Delete Cluster wizard appears. Click Delete.

#Clean IPtables on each host:
echo "Reset iptables to ACCEPT all, then flush and delete all other chains"
declare -A chains=([filter]=INPUT:FORWARD:OUTPUT [raw]=PREROUTING:OUTPUT [mangle]=PREROUTING:INPUT:FORWARD:OUTPUT:POSTROUTING [security]=INPUT:FORWARD:OUTPUT [nat]=PREROUTING:INPUT:OUTPUT:POSTROUTING)
for table in "${!chains[@]}"; do
	echo "${chains[$table]}" | tr : $"\n" | while IFS= read -r; do
		sudo iptables -t "$table" -P "$REPLY" ACCEPT
	done
	sudo iptables -t "$table" -F
	sudo iptables -t "$table" -X
done
rm -rvf /etc/rancher /var/lib/rancher /var/log/rancher

# remove agents from all hosts in CM UI
# systemctl stop cloudera-scm-agent
# dnf remove -y cloudera-manager-agent cloudera-manager-daemons
# rm -rvf /opt/cloudera/cm-agent/
