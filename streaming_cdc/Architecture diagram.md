## CDC Architecture Overview — Real-Time Inventory Updates

This architecture implements a **Change Data Capture (CDC)**–based real-time inventory pipeline.  
It captures **INSERT, UPDATE, and DELETE** operations from the source inventory database and distributes those changes in real time to multiple downstream consumers using a streaming backbone.

### Design Goals

- **Low-latency inventory updates**  
  Propagate inventory changes to downstream systems within seconds.

- **Decoupled and scalable distribution**  
  Publish changes once and allow multiple consumers to process the same events independently.

- **Separation of operational and analytical workloads**  
  Optimize real-time serving and analytical use cases through dedicated downstream paths.

### Architecture Summary

- The **source database** (PostgreSQL/MySQL) remains the system of record for inventory transactions.
- A **CDC tool** (e.g., Debezium, AWS DMS, or Fivetran) continuously reads the database transaction log and converts row-level changes into immutable CDC events.
- **Kinesis Data Streams** acts as the central streaming platform, reliably distributing inventory change events to multiple consumers in parallel.
- **AWS Lambda** processes CDC events for operational use cases, including:
  - Updating the current inventory state in DynamoDB
  - Triggering real-time alerts for low stock or anomalous changes
- **Redshift Streaming Ingestion** consumes the same event stream directly from Kinesis, enabling near real-time analytical queries and dashboards in Amazon Redshift.

### Key Characteristics

- **Event-driven**: All downstream systems react to immutable inventory change events.
- **Near real-time**: Operational and analytical consumers receive updates with low latency.
- **Replayable**: CDC events can be reprocessed from the stream for recovery or backfills.
- **Fault-tolerant**: Failures in one consumer do not impact others.

This CDC architecture is well suited for high-throughput inventory systems that require both **real-time operational visibility** and **near real-time analytics**.

、、、text

┌───────────────────────────────────────────────────────────────────────────────┐
│                     SOURCE DATABASE (PostgreSQL / MySQL)                      │
│                                                                               │
│   Inventory Table: inventory                                                  │
│   • INSERT / UPDATE / DELETE (inventory changes)                              │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │  Transaction Log / Binlog / WAL                                          │  │
│  │  • Captures all database changes (CDC source of truth)                   │  │
│  │  • Sequential log of operations                                          │  │
│  └───────────────────────────────┬─────────────────────────────────────────┘  │
└───────────────────────────────────┼───────────────────────────────────────────┘
                                    │
                                    │ (Read log)
                                    ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                     CDC TOOL (Debezium / AWS DMS / Fivetran)                  │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │  • Reads transaction log                                                 │  │
│  │  • Converts changes into CDC events (insert/update/delete)               │  │
│  │  • Publishes events to streaming platform                                │  │
│  └───────────────────────────────┬─────────────────────────────────────────┘  │
└───────────────────────────────────┼───────────────────────────────────────────┘
                                    │
                                    │ (Stream CDC events)
                                    ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                     STREAMING PLATFORM (Kinesis Data Streams)                 │
│                                                                               │
│  Stream: inventory_cdc                                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │  Event 1: {"op":"INSERT","sku":"A1","wh":101,"qty":100,"ts":"..."}       │  │
│  │  Event 2: {"op":"UPDATE","sku":"A1","wh":101,"qty": 97,"ts":"..."}       │  │
│  │  Event 3: {"op":"DELETE","sku":"B2","wh":102,"ts":"..."}                 │  │
│  └───────────────────────────────┬─────────────────────────────────────────┘  │
└───────────────────────────────────┼───────────────────────────────────────────┘
                                    │
                                    │ (Fan-out / Distribute in parallel)
               ┌────────────────────┴─────────────────────┐
               │                                          │
               ▼                                          ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                REAL-TIME OPERATIONAL CONSUMERS (Serving + Ops)                │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │  AWS Lambda (Kinesis Trigger)                                            │  │
│  │  • Decode + validate event                                               │  │
│  │  • Idempotency / dedup (avoid double-apply on retries)                   │  │
│  │  • Optional: aggregate within batch                                      │  │
│  └───────────────┬───────────────────────────────┬─────────────────────────┘  │
│                  │                               │                            │
│                  │ (Write current state)         │ (Trigger alerts)           │
│                  ▼                               ▼                            │
│   ┌───────────────────────────────────────┐     ┌─────────────────────────┐  │
│   │ DynamoDB (Current Inventory Store)    │     │ Alerting (SNS/EventBridge│  │
│   │ • Fast reads/writes for apps/APIs     │     │ /PagerDuty/Slack...)     │  │
│   │ • “What is stock NOW?”               │     │ • Low stock / anomalies  │  │
│   └───────────────────────────────────────┘     └─────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│                         ANALYTICS CONSUMERS (Near Real-time)                  │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │  Redshift Streaming Ingestion                                            │  │
│  │  • Redshift consumes Kinesis stream directly                              │  │
│  │  • Ingest into Streaming Materialized View (append-only events)          │  │
│  └───────────────────────────────┬─────────────────────────────────────────┘  │
│                                  │                                            │
│                                  │ (Query / transform)                        │
│                                  ▼                                            │
│   ┌───────────────────────────────────────────────────────────────────────┐   │
│   │ Amazon Redshift (Analytics Warehouse)                                  │   │
│   │ • Near real-time KPIs / trends                                         │   │
│   │ • Aggregations (5-min, hourly)                                         │   │
│   │ • BI dashboards / monitoring                                           │   │
│   └───────────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────────┘


