# Runbook: Redshift ETL Jobs Fail with Serialization Errors

## Severity: High
ETL jobs fail due to concurrency conflicts, causing delayed data availability.  
No data loss is expected.

---

## Detection

### Alert
- Airflow / scheduler reports ETL task failures
- Error message contains `could not serialize access` or `serialization error`

### Symptoms
- Multiple ETL jobs fail around the same time (e.g., Monday morning peak)
- Target tables are not updated
- Downstream dashboards show stale data


## Initial Response (5 minutes)

### Immediate action to stabilize

    - Pause or reduce automatic retries to avoid retry storms

    - Avoid manually killing queries unless the cluster is under severe pressure

### Notify stakeholders

    - Inform data consumers of delayed data refresh

    - Notify the data engineering team that concurrency conflicts are under investigation

### Begin investigation

    - Identify which queries failed and which queries are blocking others

## Investigation Steps (15 minutes)
1. Identify serialization errors
```sql
   SELECT
      q.query,
      q.starttime,
      q.endtime,
      u.usename,
      LEFT(e.err_reason, 200) AS err_reason
    FROM stl_query q
    JOIN pg_user u ON u.usesysid = q.userid
    JOIN stl_error e ON e.query = q.query
    WHERE q.starttime >= dateadd(hour, -6, getdate())
      AND e.err_reason ILIKE '%serializ%'
    ORDER BY q.starttime DESC;
```

3. Retrieve full SQL text for failed queries
```sql
    SELECT
      query,
      LISTAGG(text, '') WITHIN GROUP (ORDER BY sequence) AS full_sql
    FROM stl_querytext
    WHERE query IN (:query_id_1, :query_id_2)
    GROUP BY 1;
```

5. Confirm root cause

    Verify that multiple jobs are writing to the same target table
    
    Common conflicting operations:
    
    INSERT / UPDATE / DELETE
    
    MERGE
    
    COPY into the same staging or target table
   
## Resolution Steps
1: Short-term recovery

    Allow the blocking job to complete
    
    Re-run failed ETL jobs (serialization errors are transient and often succeed on retry)
    
2: Implement Python orchestration (Lock + Retry + Logging)

  To prevent future serialization conflicts, implement a Python orchestration script that ensures:
  
    - Only one job writes to a target table at a time (locking)
    
    - Transient serialization errors are retried with backoff
    
    - All steps are logged for debugging
    
3: Scheduler-level protection

    Use Airflow Pools:
    
    Assign all “write target table” tasks to the same pool (size = 1)
    
    Set max_active_runs = 1 for DAGs writing to the same table
    
## Verification
1. Confirm ETL success
    - Failed jobs rerun successfully
    
    - Target table row counts updated
2. Monitor serialization errors
   
  SELECT COUNT(*)
  FROM stl_error
  WHERE err_reason ILIKE '%serializ%'
  AND starttime > dateadd(minute, -30, getdate());
   
## Post-Incident
1. Follow-up actions

  - Document conflicting jobs and target tables

  - Clarify table ownership and write responsibilities

2. Prevention measures

  - Enforce Python-level locking for all write operations

  - Add retry logic for transient serialization errors
  - Use Airflow task dependencies and pools to control concurrency 

## Python Orchestration Script
```
import psycopg2
import time

RS_CONN = dict(
    host="your-redshift-endpoint",
    port=5439,
    dbname="dev",
    user="username",
    password="password",
)

LOCK_NAME = "write:public.fact_sales"
MAX_LOCK_WAIT_SEC = 60
MAX_RETRY = 5


def log(msg: str):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), msg)


def ensure_lock_table(cur):
    cur.execute("""
        CREATE TABLE IF NOT EXISTS etl_lock (
          lock_name   VARCHAR(200),
          acquired_at TIMESTAMP
        );
    """)


# 1) Locking mechanism
def acquire_lock(cur, conn, lock_name: str):
    deadline = time.time() + MAX_LOCK_WAIT_SEC
    while time.time() < deadline:
        log(f"[LOCK] Trying to acquire: {lock_name}")

        cur.execute("""
            INSERT INTO etl_lock (lock_name, acquired_at)
            SELECT %s, GETDATE()
            WHERE NOT EXISTS (
                SELECT 1 FROM etl_lock WHERE lock_name = %s
            );
        """, (lock_name, lock_name))
        conn.commit()

        if cur.rowcount == 1:
            log(f"[LOCK] Acquired: {lock_name}")
            return

        log("[LOCK] Busy, waiting 3 seconds...")
        time.sleep(3)

    raise TimeoutError(f"Could not acquire lock: {lock_name}")


def release_lock(cur, conn, lock_name: str):
    log(f"[LOCK] Releasing: {lock_name}")
    cur.execute("DELETE FROM etl_lock WHERE lock_name = %s;", (lock_name,))
    conn.commit()


# 2) Retry logic + 3) Logging
def run_sql_with_retry(cur, conn, sql_text: str):
    for attempt in range(1, MAX_RETRY + 1):
        try:
            log(f"[SQL] Attempt {attempt}/{MAX_RETRY}")
            cur.execute(sql_text)
            conn.commit()
            log("[SQL] Success")
            return
        except Exception as e:
            conn.rollback()
            log(f"[SQL] Failed: {e}")

            if "serializ" in str(e).lower():
                wait = 2 ** attempt
                log(f"[RETRY] Serialization error, retrying in {wait}s...")
                time.sleep(wait)
                continue

            raise


def main():
    etl_sql = """
    BEGIN;
      INSERT INTO public.fact_sales
      SELECT * FROM public.staging_sales;
    COMMIT;
    """

    log("[JOB] Start")
    conn = psycopg2.connect(**RS_CONN)
    cur = conn.cursor()

    try:
        ensure_lock_table(cur)
        conn.commit()

        acquire_lock(cur, conn, LOCK_NAME)
        run_sql_with_retry(cur, conn, etl_sql)

        log("[JOB] Completed successfully")

    finally:
        try:
            release_lock(cur, conn, LOCK_NAME)
        except Exception as e:
            log(f"[LOCK] Release failed: {e}")

        cur.close()
        conn.close()
        log("[JOB] End")


if __name__ == "__main__":
    main()
