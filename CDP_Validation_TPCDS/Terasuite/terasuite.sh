# Copyright 2026 Cloudera, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/bin/bash
source ./parameters.sh

function getHourMinSec() {
    seconds=$1
    hr=$((seconds/3600))
    tmp=$((seconds % 3600 ))
    min=$((tmp / 60))
    sec=$((seconds % 60))
    echo " ${hr}hr ${min}mins ${sec}secs "
}

echo ""
echo "..........................................................................."
printf "\n Starting Terasuite test as part of CDP Validation. \n"
echo "..........................................................................."
echo ""
echo "Data volume parameter chosen is: ${DATA_VOL}"
echo "Setting the parameter values for ${OUTPUT_DIR_PREFIX} test."

## Set the initial values for ${OUTPUT_DIR_PREFIX} terasuite
hdfs_bin=/usr/bin/hdfs
#DATA_VOL=10000000000
#DIR_PREFIX=${OUTPUT_DIR_PREFIX}
#S3A_PREFIX=s3a://cldr-ecs-obs
INPUT="${S3A_PREFIX}/tmp/CDP_Validation/Teragen/teragen_${OUTPUT_DIR_PREFIX}"
OUTPUT="${S3A_PREFIX}/tmp/CDP_Validation/Terasort/terasort_${OUTPUT_DIR_PREFIX}"
REPORT="${S3A_PREFIX}/tmp/CDP_Validation/Teravalidate/teravalidate_${OUTPUT_DIR_PREFIX}"
CDP_DIR="/opt/cloudera/parcels/CDH/lib/hadoop-mapreduce"
echo -e "INPUT=$INPUT\n OUTPUT=$OUTPUT\n REPORT=$REPORT"
#BLOCK_SIZE=134217728

printf "\nCleaning the directories if existed. \n"
## Clean the HDFS directories
$hdfs_bin dfs -rm -r -skipTrash $INPUT;
$hdfs_bin dfs -rm -r -skipTrash $OUTPUT;
$hdfs_bin dfs -rm -r -skipTrash $REPORT;

## Create HDFS directory if not exists
$hdfs_bin dfs -mkdir -p /tmp/CDP_Validation/Teragen
$hdfs_bin dfs -mkdir -p /tmp/CDP_Validation/Terasort
$hdfs_bin dfs -mkdir -p /tmp/CDP_Validation/Teravalidate

echo ""
echo "###############################################################"
echo "######################## TERAGEN TEST #########################"
echo "###############################################################"
echo ""

echo "..........................................................................."
printf " Starting with Teragen for generating ${DATA_VOL}*100 bytes (${OUTPUT_DIR_PREFIX}) of data.\n"
echo "..........................................................................."
echo ""

cmd="time yarn jar $CDP_DIR/hadoop-mapreduce-examples.jar teragen -Ddfs.replication=$REPLICATION -Ddfs.client.block.write.locateFollowingBlock.retries=15 -Dyarn.app.mapreduce.am.job.cbd-mode.enable=false -Ddfs.blocksize=$BLOCK_SIZE -Dyarn.app.mapreduce.am.job.map.pushdown=false -Dmapreduce.map.resource.vcores=$MAP_CPU -Dmapreduce.map.memory.mb=$MAP_MEMORY -Dmapreduce.job.maps=$NUM_MAPPERS $DATA_VOL $INPUT"

printf "${cmd} \n"

START_TIME="$(date +%s.%N)"
$cmd
END_TIME="$(date +%s.%N)"

RETURN_VAL=$?

if [[ "${RETURN_VAL}" == 0 ]]; then
  echo "Teragen ran successfully. "
  secs_elapsed="$(echo "$END_TIME - $START_TIME" | bc -l)"
  secs_new=$( echo $secs_elapsed | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}' )
  time=$(getHourMinSec ${secs_new})
  echo "____________________________________"
  echo "Total runtime for teragen test:-"
  echo $time
  echo "____________________________________"
else
    echo "..........................................................................."
    echo " Teragen did not run successfully. Skipping the remaining tests as well."
    echo " Status code was: ${RETURN_VAL}"
    echo "..........................................................................."
    exit ${RETURN_VAL}
fi

sleep 5
echo ""
echo "..........................................................................."
printf " Teragen is completed. \n"
echo "..........................................................................."
echo ""
echo "###############################################################"
echo "###################### TERASORT TEST ######################"
echo "###############################################################"
echo ""
echo "..........................................................................."
printf " Starting with Terasort of ${DATA_VOL}*100 bytes (${OUTPUT_DIR_PREFIX}) of data. \n"
echo "..........................................................................."
echo ""

cmd="time yarn jar $CDP_DIR/hadoop-mapreduce-examples.jar terasort -Ddfs.replication=$REPLICATION \
-Ddfs.client.block.write.locateFollowingBlock.retries=15 -Dyarn.app.mapreduce.am.job.cbd-mode.enable=false \
-Ddfs.blocksize=$BLOCK_SIZE -Dyarn.app.mapreduce.am.job.map.pushdown=false -Dmapreduce.map.resource.vcores=$MAP_CPU \
-Dmapreduce.map.memory.mb=$MAP_MEMORY -Dmapreduce.job.maps=$NUM_MAPPERS -Dmapreduce.reduce.resource.vcores=$REDUCE_CPU  -Dmapreduce.reduce.memory.mb=$REDUCE_MEMORY \
-Dmapreduce.job.reduces=$NUM_REDUCERS $INPUT $OUTPUT"

printf " ${cmd} \n"

START_TIME="$(date +%s.%N)"
$cmd
END_TIME="$(date +%s.%N)"

RETURN_VAL=$?

if [[ "${RETURN_VAL}" == 0 ]]; then
  echo "Terasort ran successfully. "
  secs_elapsed="$(echo "$END_TIME - $START_TIME" | bc -l)"
  secs_new=$( echo $secs_elapsed | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}' )
  time=$(getHourMinSec ${secs_new})
  echo "____________________________________"
  echo "Total runtime for terasort test:-"
  echo $time
  echo "____________________________________"
else
    echo "..........................................................................."
    echo " Terasort did not run successfully. Skipping the remaining test as well."
    echo " Status code was: ${RETURN_VAL}"
    echo "..........................................................................."
    exit ${RETURN_VAL}
fi

sleep 5
echo "..........................................................................."
printf " Terasort is completed. \n"
echo "..........................................................................."
echo ""
echo "###############################################################"
echo "###################### TERAVALIDATE TEST ######################"
echo "###############################################################"
echo ""
echo "..........................................................................."
printf " Starting with Teravalidate of the sorted data. \n"
echo "..........................................................................."
echo ""
cmd="time yarn jar $CDP_DIR/hadoop-mapreduce-examples.jar teravalidate -Ddfs.replication=$REPLICATION \
-Ddfs.client.block.write.locateFollowingBlock.retries=15 -Dyarn.app.mapreduce.am.job.cbd-mode.enable=false \
-Ddfs.blocksize=$BLOCK_SIZE -Dyarn.app.mapreduce.am.job.map.pushdown=false -Dmapreduce.map.resource.vcores=$MAP_CPU \
-Dmapreduce.map.memory.mb=$MAP_MEMORY -Dmapreduce.reduce.resource.vcores=$REDUCE_CPU \
-Dmapreduce.reduce.memory.mb=$REDUCE_MEMORY $OUTPUT $REPORT"

printf " ${cmd} \n"

START_TIME="$(date +%s.%N)"
$cmd
END_TIME="$(date +%s.%N)"

RETURN_VAL=$?

if [[ "${RETURN_VAL}" == 0 ]]; then
  echo "Teravalidate ran successfully. "
  secs_elapsed="$(echo "$END_TIME - $START_TIME" | bc -l)"
  secs_new=$( echo $secs_elapsed | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}' )
  time=$(getHourMinSec ${secs_new})
  echo "____________________________________"
  echo "Total runtime for teravalidate test:-"
  echo $time
  echo "____________________________________"
else
    echo "..........................................................................."
    echo " Teravalidate did not run successfully. Check for the errors and rerun only Teravalidate. "
    echo " Status code was: ${RETURN_VAL}"
    echo "..........................................................................."
    exit ${RETURN_VAL}
fi

sleep 5
echo ""
echo "..........................................................................."
printf " TERASUITE TEST RAN SUCCESSFULLY. \n"
echo "..........................................................................."
echo ""
