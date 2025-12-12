-- ======================================================
-- Step 1: Rebuild fact table with new DISTKEY + SORTKEY
-- ======================================================

CREATE TABLE fact_inventory_transactions_new
DISTKEY(warehouse_id)           -- aligns with join key, avoids DS_DIST_BOTH
SORTKEY(transaction_timestamp)  -- enables zone-map pruning for date filters
AS
SELECT *
FROM fact_inventory_transactions;

-- Swap table names (keep original table for reference)
ALTER TABLE fact_inventory_transactions RENAME TO fact_inventory_transactions_old;
ALTER TABLE fact_inventory_transactions_new RENAME TO fact_inventory_transactions;


-- ======================================================
-- Step 2: Materialized View for Monthly Aggregation
-- Reduces repeated aggregation and fact table scans.
-- ======================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_monthly_inventory AS
SELECT 
    w.warehouse_id,
    w.warehouse_name,
    p.product_id,
    p.product_category,
    DATE_TRUNC('month', t.transaction_timestamp) AS month,
    SUM(t.quantity) AS total_quantity,
    SUM(t.quantity * t.unit_cost) AS total_value
FROM fact_inventory_transactions t
JOIN dim_warehouses w 
    ON t.warehouse_id = w.warehouse_id
JOIN dim_products p 
    ON t.product_id = p.product_id
WHERE t.transaction_timestamp >= '2023-01-01'
  AND w.region = 'North America'
GROUP BY 
    w.warehouse_id,
    w.warehouse_name,
    p.product_id,
    p.product_category,
    DATE_TRUNC('month', t.transaction_timestamp);


-- ======================================================
-- Step 3: Query from the Materialized View
-- (Optimized Query)
-- ======================================================

SELECT
    warehouse_name,
    product_category,
    month,
    total_quantity,
    total_value
FROM mv_monthly_inventory
ORDER BY month DESC, total_value DESC;
