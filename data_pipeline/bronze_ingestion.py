"""
Bronze layer ingestion job for global inventory 

Scenario:
- WMS (Warehouse Management System): JSON files every 15 minutes
- E-commerce Platform: CSV files hourly
- ERP System: Parquet files daily

Requirements:
1) Create PySpark job to ingest raw data to S3 bronze layer
   - Structure: s3://global-inventory/bronze/{source_system}/year=YYYY/month=MM/day=DD/
2) Implement:
   2.1 Schema-on-read (minimal transformations)
   2.2 Add ingestion metadata (timestamp, source file, batch_id)
   2.3 Handle late-arriving data
   2.4 Partition by ingestion_date
3) Deliverable: Python script with error handling

Late Arriving Data Strategy:
In the bronze layer, we do not attempt to reorder or rewrite historical data. All files—whether on time or late—are assigned an ingestion timestamp at the moment they are read by this job. 
We then partition the output by ingestion_date (year/month/day). This ensures that:
1) Late-arriving files naturally land in the partition of the day they were ingested, not the day the business event occurred.
2) The bronze layer remains append-only and simple, avoiding complex merges.
3) Any deduplication or alignment with business event dates is handled later in the silver layer, where business rules and MERGE logic are applied.
  
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    current_timestamp,
    input_file_name,
    lit,
    to_date,
    year,
    month,
    dayofmonth,
)
import uuid

# -----------------------
# USER INPUT PARAMETERS
# -----------------------
source_system = "wms"   # wms | ecommerce | erp
input_path = "s3://landing-zone/wms/"
output_path = f"s3://global-inventory/bronze/{source_system}/"
batch_id = str(uuid.uuid4())

# file format
format_map = {
    "wms": "json",
    "ecommerce": "csv",
    "erp": "parquet"
}
file_format = format_map[source_system]

spark = SparkSession.builder.appName("BronzeIngestion").getOrCreate()

try:
    # -----------------------
    # 1. READ RAW DATA (schema-on-read)
    # -----------------------
    reader = spark.read.format(file_format)

    if file_format == "json":
        reader = reader.option("inferSchema", "false")

    if file_format == "csv":
        reader = reader.option("header", "true").option("inferSchema", "false")

    bronze_df = reader.load(input_path)

    # -----------------------
    # 2. ADD METADATA
    # -----------------------
    bronze_df = (
        bronze_df
        .withColumn("ingestion_timestamp", current_timestamp())
        .withColumn("source_file", input_file_name())
        .withColumn("batch_id", lit(batch_id))
    )

    # ingestion date → year/month/day
    bronze_df = bronze_df.withColumn("ingestion_date", to_date("ingestion_timestamp"))
    bronze_df = bronze_df.withColumn("year", year("ingestion_date"))
    bronze_df = bronze_df.withColumn("month", month("ingestion_date"))
    bronze_df = bronze_df.withColumn("day", dayofmonth("ingestion_date"))

    # -----------------------
    # 3. WRITE TO BRONZE LAYER
    # -----------------------
    (
        bronze_df.write
        .format("delta")          
        .mode("append")
        .partitionBy("year", "month", "day")
        .save(output_path)
    )

    print("✓ Bronze ingestion completed.")

except Exception as e:
    print("✗ Error during ingestion:", e)

finally:
    spark.stop()
