#!/bin/bash

function timedate() {
    TZ="${TIMEZONE}" date
    echo ""
}

function usageExit() {
    echo "Usage: sh query_runner_trino.sh SCALE FORMAT"
    echo "SCALE must be greater than 1"
    echo "FORMAT must be either 'orc' | 'parquet'"
    exit 1
}

function setupRun() {
    ID=$(TZ="${TIMEZONE}" date +"%m.%d.%Y-%H.%M.%S")

    # --- QUERY FILE NAME ---
    QUERY_BASE_NAME="queries/query"
    QUERY_FILE_EXT=".sql"

    # --- REPORT NAME ---
    REPORT_NAME="time_elapsed_Trino_tpcds"

    # --- TPC-DS SCHEMA ---
    DATABASE="cdp_hive_tpcds_bin_partitioned_managed_orc_${SCALE}"

    # --- CLOCK ---
    CLOCK_FILE="aaa_clocktime_trino.txt"

    if [[ -f "${CLOCK_FILE}" ]]; then
        rm "${CLOCK_FILE}"
    fi

    echo "Created new clock"

    # generate time report
    rm -f "${REPORT_NAME}"*.csv
    echo "query #, secs elapsed, status" > "${REPORT_NAME}.csv"

    echo "New report generated"

    # clear logs
    if [[ -d log_query/ ]]; then
        rm -r log_query/
    fi

    mkdir log_query/
    echo "Log folder generated"

    CURR_DIR="$(pwd)/"

    # Trino connection details
    TRINO_URL="https://ntnx-trino-vw.apps.ntnxlab.local:443"
}

function runBenchmark() {
    echo "Run queries for Trino TPC-DS ${FORMAT} at scale ${SCALE}" > "${CLOCK_FILE}"
    timedate >> "${CLOCK_FILE}"

    START=1
    END=99
    REPEAT=1

    for (( QUERY_NUM = START; QUERY_NUM <= END; QUERY_NUM++ )); do
        for (( j = 0; j < REPEAT; j++ )); do

            query_path="${QUERY_BASE_NAME}${QUERY_NUM}${QUERY_FILE_EXT}"
            LOG_PATH="log_query/query${QUERY_NUM}_log${j}.txt"

            ./util_internalRunQuery_trino.sh \
                "$TRINO_URL" \
                "$CURR_DIR$query_path" \
                "$CURR_DIR$LOG_PATH" \
                "$QUERY_NUM" \
                "$CURR_DIR$REPORT_NAME.csv" \
                "$DATABASE"

        done
    done

    echo "Finished" >> "${CLOCK_FILE}"
    timedate >> "${CLOCK_FILE}"
}

function generateZipReport() {

    FINAL_REPORT_LOCATION="/tmp/PSE-Benchmarks_PVK/TPC-DS/Trino_TPCDS_RESULTS/${SCALE}/"

    hdfs dfs -mkdir -p "${FINAL_REPORT_LOCATION}"
    hdfs dfs -chmod 777 "${FINAL_REPORT_LOCATION}"

    mv "${REPORT_NAME}.csv" "${REPORT_NAME}_${ID}.csv"

    zip -j log_query.zip log_query/*
    zip -r "tpcds-Trino-${SCALE}GB-${ID}.zip" log_query.zip "${REPORT_NAME}_${ID}.csv"

    rm log_query.zip

    hdfs dfs -copyFromLocal \
        "tpcds-Trino-${SCALE}GB-${ID}.zip" \
        "${FINAL_REPORT_LOCATION}tpcds-${SCALE}GB-${ID}.zip"

    echo "Results copied to HDFS: ${FINAL_REPORT_LOCATION}"
}

# ---------------- MAIN ----------------

SCALE=$1
FORMAT=$2
TIMEZONE="America/Los_Angeles"

if [[ "X$SCALE" == "X" || $SCALE -eq 1 ]]; then
    usageExit
fi

if ! [[ "$SCALE" =~ ^[0-9]+$ ]]; then
    echo "'$SCALE' is not a number!"
    usageExit
fi

if [[ "$FORMAT" != "orc" && "$FORMAT" != "parquet" ]]; then
    usageExit
fi

setupRun
runBenchmark
generateZipReport

echo "Trino TPC-DS execution complete."
