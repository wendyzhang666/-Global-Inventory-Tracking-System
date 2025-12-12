-- Scenario 1: Disk Space Crisis
-- Friday 4 PM: Alert fires - "Redshift disk usage at 94%"

-- Investigation Queries:
-- 1. Identify largest tables
-- 2. Find tables needing VACUUM
-- 3. Check for temporary table bloat
-- 4. Identify candidates for archival


-- Check disk usage
SELECT 
    node,
    used,
    capacity,
    ROUND((used::FLOAT / capacity) * 100, 2) as percent_used
FROM stv_partitions
ORDER BY percent_used DESC;

-- Find largest tables
SELECT 
    schemaname,
    tablename,
    size as size_mb,
    ROUND(size::FLOAT / 1024, 2) as size_gb
FROM svv_table_info
WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
ORDER BY size DESC
LIMIT 20;

-- Check if VACUUM needed
SELECT 
    tablename,
    unsorted,
    vacuum_sort_benefit
FROM svv_table_info
WHERE unsorted > 5  -- Tables with >5% unsorted data
ORDER BY vacuum_sort_benefit DESC;

-- Check temporary / internal worktable bloat
SELECT
  p.slice,
  p.name,
  p.rows,
  p.unsorted,
  p.size AS size_mb
FROM stv_tbl_perm p
WHERE p.size > 0
  AND (
       p.name ILIKE '%temp%'
    OR p.name ILIKE '%worktable%'
    OR p.name ILIKE '%internal%'
  )
ORDER BY p.size DESC;

-- Identify candidates for archival:
-- Big tables that haven't been scanned recently (or never scanned in the window)

WITH last_access AS (
  SELECT
    s.tbl,
    MAX(s.endtime) AS last_scan_time
  FROM stl_scan s
  WHERE s.starttime >= DATEADD(day, -180, GETDATE())  -- lookback window (adjust: 90/180/365)
  GROUP BY s.tbl
)
SELECT
  ti."schema" AS schema_name,
  ti."table"  AS table_name,
  (ti.size / 1024.0) AS size_gb,
  ti.tbl_rows,
  la.last_scan_time,
  DATEDIFF(day, la.last_scan_time, GETDATE()) AS days_since_last_scan
FROM svv_table_info ti
LEFT JOIN last_access la
  ON la.tbl = ti.table_id
WHERE ti."schema" NOT IN ('pg_catalog', 'information_schema')
  AND (ti.size / 1024.0) >= 10                          -- only tables >= 10GB (adjust)
  AND (la.last_scan_time IS NULL
       OR la.last_scan_time < DATEADD(day, -60, GETDATE()))  -- not accessed in 60 days (adjust)
ORDER BY
  la.last_scan_time NULLS FIRST,
  size_gb DESC
LIMIT 20;
