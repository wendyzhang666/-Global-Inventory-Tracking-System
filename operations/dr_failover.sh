DR Failover Procedure
Step 1: Assess Primary Region

# Check if primary region is unavailable
aws redshift describe-clusters \
    --cluster-identifier prod-cluster \
    --region us-east-1

# If timeout or error, proceed with failover
Step 2: Restore in DR Region

# Get latest snapshot from DR region
LATEST_SNAPSHOT=$(aws redshift describe-cluster-snapshots \
    --region us-west-2 \
    --cluster-identifier prod- \
    --snapshot-identifier $LATEST_SNAPSHOT
