# Large-Scale Inventory Trend Optimization (10B Row Scenario)

## Scenario

The CFO requests:

“Show me inventory value trends for the past 3 years, broken down by product category and warehouse, with year-over-year comparison.”

- Dataset size: 10 billion+ transaction rows

- Performance requirement: Query must run in < 30 seconds

- Output grain:

  - 36 months

  - 50 product categories

  - 500 warehouses

  - Monthly trend + YOY comparison

## Optimization Strategy

1. Physical Table Optimization (Sort Key + Dist Key)
- SORTKEY: transaction_timestamp

Enables zone-map pruning

Limits scan to the last 36 months, instead of the full 10B rows

DISTKEY: warehouse_id

Aligns with fact–dimension join

Enables local joins (DS_DIST_NONE)

Prevents data shuffling across nodes

Distributes data evenly (500 warehouses)

2. Pre-Aggregated Monthly Summary (month × warehouse × category)

Create a summary structure at:

month × warehouse_id × product_category

This supports:

Monthly trend analysis

YOY calculation with LAG(12)

Small data volume (~900k rows)

This summary table replaces repeated aggregation over 10B fact rows.

3. Incremental Materialized View for 3-Year Trend

Implement the monthly summary as an incrementally refreshed MV:

REFRESH MATERIALIZED VIEW processes only new fact rows

No need to recompute all 3 years

CFO query reads directly from the MV

Typical runtime: < 5 seconds

4. Offload Cold Data (> 3 Years) to S3 via Redshift Spectrum

Move older-than-3-years data to S3 in Parquet format

Expose it as an external table using Redshift Spectrum

Keep only 3 years of hot data in Redshift

Benefits:

Reduces table size by 70–80%

Faster MV refresh

Lower storage cost

Full historical access remains available via UNION queries
