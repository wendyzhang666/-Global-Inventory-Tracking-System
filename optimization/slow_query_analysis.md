# Query Optimization Report

## Original Performance
- Execution time: 120 seconds
- Data scanned: 500 GB
- Bottlenecks:
- 1. DS_DIST_BOTH join
- Redshift redistributed both tables during the join because the fact table’s distkey did not match the join key.
- 2. No zone-map pruning
- The fact table lacked a proper sortkey, so the filter on transaction_timestamp caused a full table scan.
- 3. Repeated aggregation on raw fact data
- Each query aggregated millions of transaction-level rows instead of using a pre-aggregated structure.

## Optimizations Applied
- 1. Changed DISTKEY from product_id to warehouse_id
- Workload analysis showed queries frequently join on warehouse_id.
- Fact and dimension tables now share the same distribution key, enabling local joins (DS_DIST_NONE)
- Eliminates expensive data shuffling across nodes.
- 2. Added SORTKEY on transaction_timestamp
- Queries consistently filter on: WHERE transaction_timestamp >= '2023-01-01'
- Adding a sortkey allows Redshift to use zone-map pruning, scanning only recent data blocks instead of the entire table.
- This dramatically reduces I/O and improves scan performance.
3. Introduced Materialized View for Monthly Aggregation
- Created a materialized view that pre-aggregates: monthly quantity/monthly value/warehouse + product category metrics
- This eliminates repeated: full fact-table scans/joins/aggregations

## Final Performance
- Execution time: 5 seconds (96% improvement)
- Data scanned: 20 GB
- Join type: DS_DIST_NONE (no data movement)
- Cost savings: ~$40 per query 

## Query (Before Optimization)
SELECT 
    w.warehouse_name,
    p.product_category,
    DATE_TRUNC('month', t.transaction_timestamp) as month,
    SUM(t.quantity) as total_quantity,
    SUM(t.quantity * t.unit_cost) as total_value
FROM fact_inventory_transactions t
JOIN dim_warehouses w ON t.warehouse_id = w.warehouse_id
JOIN dim_products p ON t.product_id = p.product_id
WHERE t.transaction_timestamp >= '2023-01-01'
  AND w.region = 'North America'
GROUP BY 1, 2, 3
ORDER BY month DESC, total_value DESC;
