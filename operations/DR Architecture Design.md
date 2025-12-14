# DR Architecture Design

This document describes the disaster recovery (DR) architecture for the data warehouse platform, designed to ensure business continuity in the event of a regional outage.

The solution meets the following objectives:
- **Recovery Time Objective (RTO):** 2 hours  
- **Recovery Point Objective (RPO):** 15 minutes  

The architecture uses **cross-region snapshot replication** to continuously protect data from the primary region (**US-East-1**) to the disaster recovery region (**US-West-2**). In the event of a failure in the primary region, the system supports **on-demand restoration of a Redshift cluster in the DR region**, followed by **connection and traffic redirection** to minimize downtime.

This document covers:
- Primary and DR region configurations
- Snapshot and replication strategy
- Failover process flow and recovery steps

The design prioritizes reliability, data durability, and operational simplicity while balancing cost by creating DR compute resources only during failover events.


┌─────────────────────────────────────────────────────────────┐
│                    PRIMARY REGION (US-East-1)                │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Production Redshift Cluster                         │  │
│  │  • 4 ra3.4xlarge nodes                               │  │
│  │  • Automated snapshots every 8 hours                 │  │
│  │  • Manual snapshots before major changes             │  │
│  └────────────────┬─────────────────────────────────────┘  │
│                   │                                          │
│                   │ (Continuous replication)                 │
│                   ▼                                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  S3 Bucket (Snapshots)                               │  │
│  │  • Versioning enabled                                │  │
│  │  • Cross-region replication to US-West-2            │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ (Cross-region copy)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   DISASTER RECOVERY REGION (US-West-2)       │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  S3 Bucket (DR Snapshots)                            │  │
│  │  • Receives copies from primary region               │  │
│  │  • Encrypted at rest                                 │  │
│  └────────────────┬─────────────────────────────────────┘  │
│                   │                                          │
│                   │ (On-demand restore)                      │
│                   ▼                                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  DR Redshift Cluster (Created on failover)           │  │
│  │  • Same size as production                           │  │
│  │  • Restored from latest snapshot                     │  │
│  │  • DNS updated to point applications here            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
