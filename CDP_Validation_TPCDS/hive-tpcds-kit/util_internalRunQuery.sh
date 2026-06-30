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

INTERNAL_DATABASE=$1
INTERNAL_SETTINGSPATH=$2
INTERNAL_QUERYPATH=$3
INTERNAL_LOG_PATH=$4
INTERNAL_QID=$5
INTERNAL_CSV=$6

TIME_TO_TIMEOUT=120m
MODE='default'

# Beeline command to execute
START_TIME="$(date +%s.%N)"
HIVE="jdbc:hive2://hs2-ntnx-hive-vw.apps.ntnxlab.local:443/${INTERNAL_DATABASE};transportMode=http;httpPath=cliservice;socketTimeout=60;ssl=true;trustStoreType=jks;sslTrustStore=/var/lib/cloudera-scm-agent/agent-cert/cm-auto-global_truststore.jks;trustStorePassword=320eXtvxZzbMBU61NmqQuPBsBpGr60eBXJP7AJw0TMx;retries=3;kerberosEnableCanonicalHostnameCheck=false;principal=hive/dwx-env-cdp-env-1.cdp.local@NTNXLAB.LOCAL"
echo $HIVE

if [[ "${MODE}" == 'default' ]]; then
    timeout "${TIME_TO_TIMEOUT}" beeline -u "${HIVE}" \
-f "${INTERNAL_QUERYPATH}" &>> "${INTERNAL_LOG_PATH}"
RETURN_VAL=$?
else
    echo "MODE must be 'default' "
    exit 1
fi

END_TIME="$(date +%s.%N)"

if [[ "${RETURN_VAL}" == 0 ]]; then
    secs_elapsed="$(echo "$END_TIME - $START_TIME" | bc -l)"
    echo "${INTERNAL_QID}, ${secs_elapsed}, SUCCESS" >> "${INTERNAL_CSV}"
    echo "query${INTERNAL_QID}: SUCCESS"
else
    echo "${INTERNAL_QID}, , FAILURE" >> "${INTERNAL_CSV}"
    echo "query${INTERNAL_QID}: FAILURE"
    echo "Status code was: ${RETURN_VAL}"
fi

# Misc recovery for system
sleep 20
