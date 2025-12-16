# Global Inventory Data Warehouse on Amazon Redshift

## Overview

This project demonstrates the design and implementation of a **production-grade global inventory data warehouse** on **Amazon Redshift**, capable of handling **real-time inventory updates**, **billions of historical records**, and **executive-level analytics** with strict performance requirements.

The system reflects real-world e-commerce complexity by combining **batch processing**, **streaming CDC ingestion**, **scalable data modeling**, and **production operations** such as incident handling and disaster recovery.

---

## Business Context

**Scenario:**  
You are at **GlobalRetail Inc.**, a global e-commerce company managing inventory across multiple regions and channels.

**Scale:**
- 500+ warehouses across North America, Europe, and Asia  
- 100K+ SKUs  
- 1M+ inventory transactions per day  
- Billions of historical transaction records  

**Target Users:**
- Supply Chain Teams  
- Operations Leaders  
- Finance & Executive Stakeholders  

**Core Business Questions:**
- How has inventory value trended over the past 3 years?
- How do trends compare year-over-year (YoY)?
- How can these insights be delivered in seconds despite massive data volume?

---

## Key Outcomes

- Built a **scalable Redshift data warehouse** using medallion architecture  
- Delivered **business-ready Gold layer metrics** as a single source of truth  
- Achieved **< 30-second query latency** on 10B+ row analytical queries  
- Enabled **near real-time inventory updates** via CDC streaming  
- Designed **production-ready runbooks** for incidents and disaster recovery  
- Demonstrated end-to-end ownership: architecture, modeling, performance, and operations  

---

## Technology Stack

- **Amazon Redshift** – columnar analytics warehouse  
- **Redshift Streaming Ingestion** – low-latency CDC ingestion  
- **Kinesis Data Streams** – real-time inventory event capture  
- **AWS Lambda** – event validation and transformation  
- **SQL** – data modeling and performance tuning  
- **Materialized Views** – incremental pre-aggregation  
- **Python** – data simulation and validation  
- **dbt** – transformations, data quality checks, and documentation  

---

## Architecture Design

### Medallion Architecture

The warehouse follows a **Bronze / Silver / Gold** medallion architecture to clearly separate **ingestion**, **transformation**, and **analytics**, while enforcing **data quality and reliability** through dbt.

#### Bronze Layer
- Raw batch data and streaming CDC events  
- Append-only ingestion with minimal transformation  
- Preserves source fidelity for auditability  

#### Silver Layer
- Cleansed and standardized datasets  
- Conformed dimensions and validated fact tables  
- **dbt data quality checks**, including:
  - `not_null` and `unique` constraints on primary keys  
  - Referential integrity checks between facts and dimensions  
  - Schema consistency and freshness validation  

#### Gold Layer
- Business-ready tables and metrics  
- Optimized for analytics and executive dashboards  
- **dbt tests ensure metric correctness and consistency**  
- Acts as the **single source of truth**  

---

### Real-Time Streaming (CDC)

To support near real-time inventory visibility:

- **Kinesis Data Streams** capture inventory change events (insert/update/delete)  
- **AWS Lambda** validates, deduplicates, and standardizes incoming events  
- **Redshift Streaming Ingestion** loads CDC data with low latency  
- CDC changes are merged into Silver and Gold analytical models  

**Deliverables:**
- End-to-end streaming architecture diagram  
- Event processing and ingestion code  

---

## Data Modeling

- Designed a **Star Schema** optimized for inventory analytics  
- Clear separation of **fact tables** and **dimension tables**  
- Carefully chosen grain to balance flexibility and performance  
- Monthly-grain Gold tables support trend and YoY analysis  

---

## Performance Optimization Strategies

To support large-scale analytics efficiently:

- Time-based **SORTKEYs** for partition pruning  
- Carefully chosen **DISTKEYs** to minimize data shuffling  
- **Pre-aggregated summary tables** at monthly grain  
- **Incremental Materialized Views** to avoid full table scans  
- **Cold data offloading** using Redshift Spectrum for data older than 3 years  

### Performance Results

- Query runtime: **< 30 seconds**  
- Data volume: **10 billion transaction records**  
- Query dimensions:
  - 50 product categories  
  - 500 warehouses  
  - 36 months  
- Enables CFO-level YoY inventory trend analysis in seconds  

---

## Incident Handling

Implemented **production-style incident response runbooks** for common warehouse issues:

- Disk space exhaustion  
- Query serialization deadlocks  

Each runbook includes:
- Detection and monitoring queries  
- Root cause analysis steps  
- Resolution and prevention strategies  

---

## Disaster Recovery

Designed and documented a **Disaster Recovery (DR) failover strategy**:

- Step-by-step failover procedures  
- Verification checklist to confirm data integrity  
- Rollback plan for partial or failed recovery  
- Failover drill documentation to validate readiness  

---

## Repository Structure

The repository is organized to mirror a real production data platform, with clear separation between architecture, pipelines, optimization, and operations:
```text
global-inventory-project/
├── README.md
├── architecture
├── data_pipeline/
│ ├── bronze_ingestion.py
│ ├── silver_transformations.sql
│ └── gold_aggregations.sql
├── optimization/
│ ├── slow_query_analysis.md
│ ├── optimized_queries.sql
│ └── explain_plans.txt
├── operations/
│ ├── runbook_disk_space.md
│ ├── runbook_serialization.md
│ ├── dr_failover.sh
│ └── monitoring_queries.sql
└── bonus/
├── streaming_cdc/
├── cost_analysis/
└── auto_maintenance/
