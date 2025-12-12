-- ============================================================
-- Gold Layer: Daily Inventory Snapshot
--
-- Purpose:
--   This table aggregates inventory data at the 
--   (snapshot_date, warehouse_id, product_id) level and computes 
--   key supply chain metrics for reporting and decision-making.
--
-- Metrics Calculated:
--   1. days_of_supply:
--        How many days current inventory can support,
--        calculated as:
--          total_quantity / avg_daily_sales_7d
--
--   2. reorder_flag:
--        Boolean indicator that triggers replenishment when
--        days_of_supply < 7 days.
--
--   3. stockout_risk:
--        Categorizes stockout risk as:
--            - HIGH    (< 3 days of supply)
--            - MEDIUM  (3–7 days)
--            - LOW     (> 7 days)
--            - UNKNOWN (no sales history)
-- ============================================================

CREATE TABLE gold.daily_inventory_snapshot AS
WITH aggregated AS (
    SELECT
        snapshot_date,
        warehouse_id,
        product_id,

        -- Inventory roll-up metrics
        SUM(quantity_on_hand)              AS total_quantity,
        AVG(unit_cost)                     AS avg_unit_cost,
        SUM(quantity_on_hand * unit_cost)  AS total_value,
        AVG(avg_daily_sales_7d)            AS avg_daily_sales_7d
    FROM silver.inventory_transactions
    GROUP BY 1，2，3
)

SELECT
    snapshot_date,
    warehouse_id,
    product_id,
    total_quantity,
    avg_unit_cost,
    total_value,
    avg_daily_sales_7d,

    ----------------------------------------------------------
    -- 1) Days of Supply
    ----------------------------------------------------------
    CASE
        WHEN avg_daily_sales_7d IS NULL OR avg_daily_sales_7d <= 0
            THEN NULL
        ELSE total_quantity / avg_daily_sales_7d
    END AS days_of_supply,

    ----------------------------------------------------------
    -- 2) Reorder Flag
    ----------------------------------------------------------
    CASE
        WHEN avg_daily_sales_7d IS NULL OR avg_daily_sales_7d <= 0
            THEN FALSE
        WHEN total_quantity / avg_daily_sales_7d < 7
            THEN TRUE
        ELSE FALSE
    END AS reorder_flag,

    ----------------------------------------------------------
    -- 3) Stockout Risk Categorization
    ----------------------------------------------------------
    CASE
        WHEN avg_daily_sales_7d IS NULL OR avg_daily_sales_7d <= 0
            THEN 'UNKNOWN'
        WHEN total_quantity / avg_daily_sales_7d < 3
            THEN 'HIGH'
        WHEN total_quantity / avg_daily_sales_7d < 7
            THEN 'MEDIUM'
        ELSE 'LOW'
    END AS stockout_risk

FROM aggregated;
