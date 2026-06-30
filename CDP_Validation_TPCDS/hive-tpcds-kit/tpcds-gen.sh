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
	echo "Usage: tpcds-gen.sh --scale <scale_factor> [--dir <temp_directory>]"
	exit 1
}

function runcommand {
	if [ "X$DEBUG_SCRIPT" != "X" ]; then
		$1
	else
		$1 2>/dev/null
	fi
}

if [ ! -f tpcds-gen/target/tpcds-gen-1.0-SNAPSHOT.jar ]; then
	echo "Please build the data generator with ./tpcds-build.sh first"
	exit 1
fi
which hive > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Script must be run where Hive is installed"
	exit 1
fi

# Get the parameters.
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
    *)
      PRG_ARGS="${PRG_ARGS} \"$1\""
      shift
  esac
done

#SCALE=$1
#DIR=$2

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
if [ X"$SCALE" = "X" ]; then
	usage
fi
if [ X"$DIR" = "X" ]; then
	DIR=/tmp/tpcds-generate
fi
if [ $SCALE -eq 1 ]; then
	echo "Scale factor must be greater than 1"
	exit 1
fi

# Do the actual data load.
hdfs dfs -mkdir -p ${DIR}
hdfs dfs -ls ${DIR}/${SCALE} > /dev/null
if [ $? -ne 0 ]; then
	echo "Generating data at scale factor $SCALE."
	(cd tpcds-gen; hadoop jar target/*.jar -d ${DIR}/${SCALE}/ -s ${SCALE})
fi
hdfs dfs -ls ${DIR}/${SCALE} > /dev/null
if [ $? -ne 0 ]; then
	echo "Data generation failed, exiting."
	exit 1
fi

hadoop fs -chmod -R 777  ${DIR}/${SCALE}

echo "TPC-DS text data generation complete."

# Assuming we are running the default hive/beeline connection (beeline-site.xml) and as the user
# EDIT THIS COMMAND AS PER YOUR ENVIRONMENT#
#-------------------------------------------#
HIVE=''
#-------------------------------------------#

# Create the text/flat tables as external tables. These will be later be converted to ORCFile.
echo "Loading text data into external tables."
runcommand "$HIVE  -i settings/load-flat.sql -f ddl-tpcds/text/alltables.sql --hivevar DB=cdp_hive_tpcds_text_${SCALE} --hivevar LOCATION=${DIR}/${SCALE}"
