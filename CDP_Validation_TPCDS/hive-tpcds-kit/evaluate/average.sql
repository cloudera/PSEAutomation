USE ${DB};

-- Test that we see data.
SELECT *
FROM
    tpcds_queries
where
     start_query = 'query60.sql'
  or end_query = 'query60.sql'
limit 10;

-- TOTAL Time (average) across the queries for each dimension.
WITH
    CORRELATE AS (
        SELECT
            s.db,
            s.start_query       as query,
            s.marker            as began,
            e.marker            as completed,
            e.marker - s.marker as lapsed_seconds
        FROM
            tpcds_queries s
                INNER JOIN tpcds_queries e
                           on s.db = e.db
                               and s.start_query = e.end_query
                               and s.marker < e.marker
        WHERE
                s.start_query != ""
    ),
    RANKED_CORRELATED AS (
        SELECT
            db,
            query,
            began,
            completed,
            lapsed_seconds,
            rank() over (partition by db, query, began order by lapsed_seconds asc) rank
        FROM
            CORRELATE
    ),
    MATCHED_QUERY AS (
        SELECT
            db,
            query,
            began,
            completed,
            lapsed_seconds
        FROM
            RANKED_CORRELATED
        WHERE
                rank = 1
    ),
    BREAKDOWN AS (
        SELECT
            --db,
            case
                WHEN size(split(db, "_")) = 6 THEN
                    case
                        when split(db, "_")[3] = "managed" then
                            true
                        else
                            false
                        end
                ELSE
                    case
                        when split(db, "_")[4] = "managed" then
                            true
                        else
                            false
                        end
                END                                  MANAGED,
            case
                WHEN size(split(db, "_")) = 6 THEN
                    true
                ELSE
                    false
                END                                  PARTITIONED,
            split(db, "_")[size(split(db, "_")) - 2] FORMAT,
            split(db, "_")[size(split(db, "_")) - 1] SCALE,
            query,
            AVG(
                    lapsed_seconds)                  avg_lapsed_seconds
        FROM
            MATCHED_QUERY
        GROUP BY
            db, query
    )
SELECT
    MANAGED,
    PARTITIONED,
    FORMAT,
    SCALE,
    sum(avg_lapsed_seconds) TOTAL_SECONDS
FROM
    BREAKDOWN
group by
    MANAGED, PARTITIONED, FORMAT, SCALE
ORDER BY TOTAL_SECONDS ASC;


-- Detailed breakdown of query averages across dimensions.
WITH
    CORRELATE AS (
        SELECT
            s.db,
            s.start_query       as query,
            s.marker            as began,
            e.marker            as completed,
            e.marker - s.marker as lapsed_seconds
        FROM
            tpcds_queries s
                INNER JOIN tpcds_queries e
                           on s.db = e.db
                               and s.start_query = e.end_query
                               and s.marker < e.marker
        WHERE
            s.start_query != ""
    ),
    RANKED_CORRELATED AS (
        SELECT
            db,
            query,
            began,
            completed,
            lapsed_seconds,
            rank() over (partition by db, query, began order by lapsed_seconds asc) rank
        FROM
            CORRELATE
    ),
    MATCHED_QUERY AS (
        SELECT
            db,
            query,
            began,
            completed,
            lapsed_seconds
        FROM
            RANKED_CORRELATED
        WHERE
            rank = 1
    ),
    BREAKDOWN AS (
        SELECT
            --db,
            case
                WHEN size(split(db, "_")) = 6 THEN
                    case
                        when split(db, "_")[3] = "managed" then
                            true
                        else
                            false
                        end
                ELSE
                    case
                        when split(db, "_")[4] = "managed" then
                            true
                        else
                            false
                        end
                END                                  MANAGED,
            case
                WHEN size(split(db, "_")) = 6 THEN
                    true
                ELSE
                    false
                END                                  PARTITIONED,
            split(db, "_")[size(split(db, "_")) - 2] FORMAT,
            split(db, "_")[size(split(db, "_")) - 1] SCALE,
            query,
            AVG(
                    lapsed_seconds)                  avg_lapsed_seconds
        FROM
            MATCHED_QUERY
        GROUP BY
            db, query
    )

SELECT
    QUERY,
    avg_lapsed_seconds,
    MANAGED,
    PARTITIONED,
    FORMAT,
    SCALE
FROM
    BREAKDOWN
ORDER BY
    query, avg_lapsed_seconds;

-- Individual Query Results - Detailed
WITH
    CORRELATE AS (
        SELECT
            s.db,
            s.start_query       as query,
            s.marker            as began,
            e.marker            as completed,
            e.marker - s.marker as lapsed_seconds
        FROM
            tpcds_queries s
                INNER JOIN tpcds_queries e
                           on s.db = e.db
                               and s.start_query = e.end_query
                               and s.marker < e.marker
        WHERE
                s.start_query != ""
    ),
    RANKED_CORRELATED AS (
        SELECT
            db,
            query,
            began,
            completed,
            lapsed_seconds,
            rank() over (partition by db, query, began order by lapsed_seconds asc) rank
        FROM
            CORRELATE
    ),
    MATCHED_QUERY AS (
        SELECT
            db,
            query,
            began,
            completed,
            lapsed_seconds
        FROM
            RANKED_CORRELATED
        WHERE
                rank = 1
    ),
    BREAKDOWN AS (
        SELECT
            --db,
            case
                WHEN size(split(db, "_")) = 6 THEN
                    case
                        when split(db, "_")[3] = "managed" then
                            true
                        else
                            false
                        end
                ELSE
                    case
                        when split(db, "_")[4] = "managed" then
                            true
                        else
                            false
                        end
                END                                  MANAGED,
            case
                WHEN size(split(db, "_")) = 6 THEN
                    true
                ELSE
                    false
                END                                  PARTITIONED,
            split(db, "_")[size(split(db, "_")) - 2] FORMAT,
            split(db, "_")[size(split(db, "_")) - 1] SCALE,
            query,
            lapsed_seconds lapsed_seconds
        FROM
            MATCHED_QUERY
    )

SELECT
    QUERY,
    lapsed_seconds,
    MANAGED,
    PARTITIONED,
    FORMAT,
    SCALE
FROM
    BREAKDOWN
ORDER BY
    query, lapsed_seconds;

-- original
select
    db,
    query,
    AVG(lapse_seconds) avg_lapse_seconds
from
    (
        SELECT
            db,
            query,
            began,
            completed,
            lapse_seconds,
            rank() over (partition by db, query, began order by lapse_seconds asc) rank
        FROM
            (
                SELECT
                    s.db,
                    s.start_query       as query,
                    s.marker            as began,
                    e.marker            as completed,
                    e.marker - s.marker as lapse_seconds
                FROM
                    tpcds_queries s
                        INNER JOIN tpcds_queries e
                                   on s.db = e.db
                                       and s.start_query = e.end_query
                                       and s.marker < e.marker) set1) rank1
where
    rank1.rank = 1
GROUP BY
    db, query
order by
    query, avg_lapse_seconds;
