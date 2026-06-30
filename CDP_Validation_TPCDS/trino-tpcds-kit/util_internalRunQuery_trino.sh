#!/bin/bash

TRINO_URL=$1
INTERNAL_QUERYPATH=$2
INTERNAL_LOG_PATH=$3
INTERNAL_QID=$4
INTERNAL_CSV=$5
DATABASE=$6

TIME_TO_TIMEOUT=120m

START_TIME="$(date +%s.%N)"

# Run Trino query
timeout "${TIME_TO_TIMEOUT}" /root/trino.jar \
"${TRINO_URL}" \
--insecure \
--user ygulati \
--password \
--catalog hive \
--schema "${DATABASE}" \
--file "${INTERNAL_QUERYPATH}" \
&>> "${INTERNAL_LOG_PATH}"

RETURN_VAL=$?

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

sleep 5
