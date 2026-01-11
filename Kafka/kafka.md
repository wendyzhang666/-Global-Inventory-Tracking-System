# Kafka Configuration — Inventory Streaming Platform

Real-time inventory streaming from **WMS, ERP, and Supplier Systems** to support:

- Operations live dashboards  
- Replenishment alerts  
- Historical analytics & reporting  

---

## 1. Kafka Topics

### inventory.moves — High-volume Event Stream  
Real-time inventory movements from WMS and ERP (receipts, picks, adjustments).

```properties
partitions=12
replication.factor=3
cleanup.policy=delete
retention.ms=2592000000          # 30 days
min.insync.replicas=2
compression.type=lz4

### restock.alerts — Low-volume Alert Stream 
Low-stock and replenishment signals for operations.

```properties
partitions=3
replication.factor=3
cleanup.policy=delete
retention.ms=604800000           # 7 days
min.insync.replicas=2
compression.type=lz4

### inventory.current.state — Compacted State Topic
Latest inventory snapshot per (warehouse_id, product_id)

```properties
partitions=6
replication.factor=3
cleanup.policy=compact
retention.ms=-1                  # keep forever (controlled by compaction)
min.insync.replicas=2
delete.retention.ms=86400000     # keep tombstones for 1 day
compression.type=lz4

### supplier.deliveries — Event Stream
Supplier shipment and receipt events.

```properties
partitions=6
replication.factor=3
cleanup.policy=delete
retention.ms=7776000000          # 90 days
min.insync.replicas=2
compression.type=lz4

### order.fulfillment — Event Stream
Order lifecycle events: pick → pack → ship → deliver.

```properties
partitions=12
replication.factor=3
cleanup.policy=delete
retention.ms=2592000000          # 30 days
min.insync.replicas=2
compression.type=lz4

## 2. Kafka Consumer Groups

### analytics-dashboard-v1 — Historical Analytics 
Full replay for reporting, trends, and backfills.

```properties
group.id=analytics-dashboard-v1
auto.offset.reset=earliest       # start from beginning for full history
enable.auto.commit=false         # commit only after successful processing

### alerts-v1 — Real-time Operations 
Near-real-time monitoring of stock and replenishment signals.

```properties
group.id=alerts-v1
auto.offset.reset=latest         # only consume new events
enable.auto.commit=true          # low-latency, best-effort delivery
auto.commit.interval.ms=1000

