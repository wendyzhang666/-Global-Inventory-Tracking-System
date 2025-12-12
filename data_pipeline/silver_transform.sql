-- models/silver_inventory_transactions.sql

/*
Transformation & Data Quality Rules (Silver Layer)
---------------------------------------------------
This model performs the following operations:

1. Standardizes column names into snake_case
2. Casts raw string fields into appropriate data types
3. Implements deduplication (latest ingestion_timestamp wins)
4. Adds row-level data quality flags:
   - Negative quantity
   - Missing warehouse_id / product_id / sku
   - Missing critical fields
   - Invalid warehouse_id (not found in dimension table)
5. Prepares the dataset for gold-layer aggregations and business logic

Data Quality Requirements:
- < 0.1% duplicate records
- < 1% NULL values in critical fields
- 100% valid warehouse_id references
*/

WITH bronze_source AS (
    SELECT *
    FROM bronze.inventory_raw
    WHERE ingestion_date = CURRENT_DATE
),

/* -----------------------------------------------------------
   1) Cleaning + Type Casting + Standardizing column names
----------------------------------------------------- */
cleaned AS (
    SELECT
        -- Type casting
        CAST(transaction_id AS BIGINT)                               AS transaction_id,
        TO_TIMESTAMP(timestamp_string, 'YYYY-MM-DD HH24:MI:SS')       AS transaction_timestamp,
        CAST(warehouse_id AS INT)                                     AS warehouse_id,
        CAST(product_id AS INT)                                       AS product_id,
        LOWER(TRIM(sku))                                              AS sku,
        LOWER(TRIM(transaction_type))                                 AS transaction_type,
        CAST(quantity AS NUMERIC(18, 2))                              AS quantity,
        CAST(unit_price AS NUMERIC(18, 2))                            AS unit_price,

        -- Normalize optional columns
        COALESCE(currency, 'USD')                                     AS currency,

        -- Metadata
        ingestion_timestamp,
        ingestion_date,
        source_system,
        source_file,
        batch_id,

        -- Row-level data quality checks
        CASE WHEN quantity < 0 THEN TRUE ELSE FALSE END               AS is_negative_qty,
        CASE WHEN warehouse_id IS NULL THEN TRUE ELSE FALSE END       AS is_missing_warehouse_id,
        CASE WHEN product_id IS NULL THEN TRUE ELSE FALSE END         AS is_missing_product_id,
        CASE WHEN sku IS NULL OR sku = '' THEN TRUE ELSE FALSE END    AS is_missing_sku,

        -- A single flag to track NULLs in critical fields
        CASE
            WHEN transaction_id IS NULL
              OR TO_TIMESTAMP(timestamp_string, 'YYYY-MM-DD HH24:MI:SS') IS NULL
              OR warehouse_id IS NULL
              OR product_id IS NULL
              OR quantity IS NULL
            THEN TRUE ELSE FALSE
        END                                                           AS has_null_in_critical_cols

    FROM bronze_source
),

/* ----------------------------------------------------
   2) Validate warehouse_id against dimension table
      - A valid record MUST match dim.warehouse
----------------------------------------------------- */
with_warehouse_ref AS (
    SELECT
        c.*,
        CASE
            WHEN c.warehouse_id IS NULL THEN TRUE               -- already flagged as missing
            WHEN w.warehouse_id IS NULL THEN TRUE               -- missing in dimension table
            ELSE FALSE
        END AS is_invalid_warehouse_id
    FROM cleaned c
    LEFT JOIN dim.warehouse w
        ON c.warehouse_id = w.warehouse_id
),

/* ----------------------------------------------------
   3) Deduplication:
      - Keep the latest record per transaction_id
      - Based on ingestion_timestamp descending
----------------------------------------------------- */
deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY transaction_id
            ORDER BY ingestion_timestamp DESC
        ) AS row_num
    FROM with_warehouse_ref
)

/* ----------------------------------------------------
   Final Output:
   - Only 1 surviving row per transaction_id
   - Includes data quality flags and standardized fields
----------------------------------------------------- */
SELECT
    transaction_id,
    transaction_timestamp,
    warehouse_id,
    product_id,
    sku,
    transaction_type,
    quantity,
    unit_price,
    currency,
    ingestion_timestamp,
    ingestion_date,
    source_system,
    source_file,
    batch_id,

    -- Data Quality Flags
    is_negative_qty,
    is_missing_warehouse_id,
    is_missing_product_id,
    is_missing_sku,
    has_null_in_critical_cols,
    is_invalid_warehouse_id

FROM deduped
WHERE row_num = 1;
