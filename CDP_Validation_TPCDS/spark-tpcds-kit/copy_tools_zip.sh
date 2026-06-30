#!/bin/bash

# Script may expect input for commands and cannot be executed in the background

USERNAME=$1
PEM_FILE_PATH=$2
HOSTS=$3

IFS=','
read -ra all_hosts <<< "$HOSTS"

USER_HOME="/home/$USERNAME"

# wget https://github.infra.cloudera.com/santhosh/dex-workloads/raw/sdx-demo/performance/tools.zip -O /home/systest/tools.zip
# unzip /home/systest/tools.zip  -d /home/systest

for host in "${all_hosts[@]}"
do
  ssh -i $PEM_FILE_PATH $USERNAME@$host "rm -rf $USER_HOME/tools; wget https://github.infra.cloudera.com/santhosh/dex-workloads/raw/sdx-demo/performance/tools.zip -O $USER_HOME/tools.zip; unzip $USER_HOME/tools.zip  -d $USER_HOME"
done
