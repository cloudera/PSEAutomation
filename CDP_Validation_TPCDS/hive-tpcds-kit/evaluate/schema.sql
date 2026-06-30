USE ${DB};

CREATE EXTERNAL TABLE tpcds_queries
(
    ignore      String,
    db          String,
    start_query String,
    end_query   String,
    marker      bigint
)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY "|"
    STORED AS TEXTFILE
    LOCATION "${LOCATION}";
