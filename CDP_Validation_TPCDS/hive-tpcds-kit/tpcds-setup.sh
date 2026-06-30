# Copyright 2022 Cloudera, Inc. All Rights Reserved.
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

function usage {
        echo "Usage: tpcds-setup.sh --scale <scale_factor> [--dir <temp_directory>] [--no-part] [--external] [--format <serde_format>]"
        exit 1
}

function runcommand {
        if [ "X$DEBUG_SCRIPT" != "X" ]; then
                $1
        else
                $1 2>/dev/null
        fi
}

which hive > /dev/null 2>&1
if [ $? -ne 0 ]; then
        echo "Script must be run where Hive is installed"
        exit 1
fi

# Tables in the TPC-DS schema.
DIMS="date_dim time_dim item customer customer_demographics household_demographics customer_address store promotion warehouse ship_mode reason income_band call_center web_page catalog_page web_site"
FACTS="store_sales store_returns web_sales web_returns catalog_sales catalog_returns inventory"

# Defaults
STRATEGY="partitioned"
TYPE="managed"
FORMAT="orc"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -D*)
      APP_JAVA_OPTS="${APP_JAVA_OPTS} ${1}"
      shift
      ;;
    --scale)
      shift
      SCALE=$1
      shift
      ;;
    --dir)
      shift
      DIR=$1
      shift
      ;;
    --no-part)
      shift
      STRATEGY="not_partitioned"
      ;;
    --external)
      shift
      TYPE="external"
      ;;
    --format)
      shift
      FORMAT=$1
      shift
      ;;
    *)
      PRG_ARGS="${PRG_ARGS} \"$1\""
      shift
  esac
done

if [ "X$BUCKET_DATA" != "X" ]; then
        BUCKETS=13
        RETURN_BUCKETS=13
else
        BUCKETS=1
        RETURN_BUCKETS=1
fi

if [ "X$DEBUG_SCRIPT" != "X" ]; then
        set -x
fi

# Sanity checking.
if [ "X$SCALE" = "X" ]; then
        usage
fi

if [ "X$DIR" = "X" ]; then
        DIR=/tmp/tpcds-generate
fi

if [ $SCALE -eq 1 ]; then
        echo "Scale factor must be greater than 1"
        exit 1
fi

if [ "$TYPE" = "external" ]; then
  LEGACY="true"
else
  LEGACY="false"
fi

# Check that data exists
hdfs dfs -mkdir -p ${DIR}
hdfs dfs -ls ${DIR}/${SCALE} > /dev/null
if [ $? -ne 0 ]; then
  echo "Run tpcds-gen.sh script first to build base generated data."
  exit 1
fi

# ------------------------------
# UPDATED: Use correct Beeline command
# ------------------------------
HIVE=''
# ------------------------------

LOAD_FILE="load_${STRATEGY}_${TYPE}_${FORMAT}_${SCALE}.mk"
SILENCE="2> /dev/null 1> /dev/null"
if [ "X$DEBUG_SCRIPT" != "X" ]; then
        SILENCE=""
fi

echo -e "all: ${DIMS} ${FACTS}" > $LOAD_FILE

i=1
total=24

DATABASE=cdp_hive_tpcds_bin_${STRATEGY}_${TYPE}_${FORMAT}_${SCALE}
DDL_DIR=bin_${STRATEGY}

echo -e "Running with... "
echo -e "      Database: ${DATABASE}"
echo -e "      Strategy: ${STRATEGY}"
echo -e "      Type:     ${TYPE}"
echo -e "      FORMAT:   ${FORMAT}"
echo -e "      SCALE:    ${SCALE}"

MAX_REDUCERS=2500 # maximum number of useful reducers for any scale
REDUCERS=$((test ${SCALE} -gt ${MAX_REDUCERS} && echo ${MAX_REDUCERS}) || echo ${SCALE})

# Populate the smaller tables.
for t in ${DIMS}
do
        COMMAND="$HIVE -i settings/load-partitioned.sql -f ddl-tpcds/bin_${STRATEGY}/${t}.sql \
            --hivevar DB=${DATABASE} --hivevar SOURCE=cdp_hive_tpcds_text_${SCALE} \
      --hivevar SCALE=${SCALE} --hivevar LEGACY=${LEGACY} \
            --hivevar REDUCERS=${REDUCERS} \
            --hivevar FILE=${FORMAT}"
        echo -e "${t}:\n\t@$COMMAND $SILENCE && echo 'Optimizing table $t ($i/$total).'" >> $LOAD_FILE
        i=`expr $i + 1`
done

for t in ${FACTS}
do
        COMMAND="$HIVE -i settings/load-partitioned.sql -f ddl-tpcds/bin_${STRATEGY}/${t}.sql \
            --hivevar DB=${DATABASE} \
      --hivevar SCALE=${SCALE} --hivevar LEGACY=${LEGACY} \
            --hivevar SOURCE=cdp_hive_tpcds_text_${SCALE} --hivevar BUCKETS=${BUCKETS} \
            --hivevar RETURN_BUCKETS=${RETURN_BUCKETS} --hivevar REDUCERS=${REDUCERS} --hivevar FILE=${FORMAT}"
        echo -e "${t}:\n\t@$COMMAND $SILENCE && echo 'Optimizing table $t ($i/$total).'" >> $LOAD_FILE
        i=`expr $i + 1`
done

make -j 1 -f $LOAD_FILE

echo "Loading constraints"
runcommand "$HIVE -f ddl-tpcds/bin_${STRATEGY}/add_constraints.sql --hivevar DB=${DATABASE}"

echo "Data loaded into database ${DATABASE}."
