-- Combined Data Quality Test:
-- 1) Duplicate records must be < 0.1%
-- 2) NULL values in critical fields must be < 1%

WITH base AS (
    SELECT *
    FROM {{ ref('silver_transform') }}
),

stats AS (
    SELECT
        COUNT(*) AS total_records,
        COUNT(*) - COUNT(DISTINCT transaction_id) AS duplicate_records,
        SUM(
            CASE
                WHEN transaction_id IS NULL
                  OR transaction_timestamp IS NULL
                  OR warehouse_id IS NULL
                  OR product_id IS NULL
                  OR quantity IS NULL
                THEN 1 ELSE 0
            END
        ) AS null_records
    FROM base
),

failures AS (
    SELECT
        'duplicate_rate_exceeded' AS test_name,
        duplicate_records / total_records AS metric_value
    FROM stats
    WHERE duplicate_records / total_records > 0.001   -- 0.1%

    UNION ALL

    SELECT
        'null_rate_exceeded' AS test_name,
        null_records / total_records AS metric_value
    FROM stats
    WHERE null_records / total_records > 0.01          -- 1%
)

SELECT *
FROM failures;
