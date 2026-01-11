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
