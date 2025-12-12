# RUNBOOK: Redshift Disk Space Crisis

## Scenario
Friday 4 PM: Alert fires — **"Redshift disk usage at 94%"**

## Severity
HIGH (P1)  
⚠️ Risk of query failures, disk spill, and cluster instability if not mitigated.

---

## Detection

- **Alert:** CloudWatch alarm "RedshiftDiskSpaceUsage"
- **Symptom:**
  - Queries failing with disk space or spill errors
  - Sudden performance degradation

---

## Initial Response (First 5 minutes)

1. **Acknowledge alert** and confirm disk usage level
2. **Post in #incidents Slack channel**:
   > ⚠️ P1: Redshift disk usage at 94%. Investigating root cause.
3. **Pause non-critical jobs**
   - Ad-hoc analytics
   - Large backfills or refresh jobs

---

## Investigation (First 15 minutes)

### 1. Identify largest tables
### 2. Find tables needing VACUUM
### 3. Check for temporary table / worktable bloat
### 4. Identify candidates for archival

---

## Resolution Steps

### 1. Immediate (same day)
        - Run VACUUM on large, highly unsorted tables
        - Cancel or throttle disk-based queries
        - Drop unused temporary or staging tables if safe

### 2. Short-term (1–2 days)
        - Archive cold data (UNLOAD to S3 or move to Spectrum)
        - Review ETL patterns causing frequent disk spill

### 3. Long-term Prevention
        - Schedule regular VACUUM / ANALYZE
        - Optimize sort keys and distribution styles
        - Set query limits for ad-hoc users
        - Monitor disk-based queries proactively
---

## Verification
      - Disk usage drops below 85%
      - No new disk-related alerts
      - Queries complete without spill or disk errors
---

## Post-Incident
      - Post resolution update in #incidents
      - Summarize root cause/ tables involved/ queries causing disk spill
      - Summarize action items
      - Create follow-up ticket for prevention work
