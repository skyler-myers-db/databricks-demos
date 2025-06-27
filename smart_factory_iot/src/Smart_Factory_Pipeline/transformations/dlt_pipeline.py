import dlt
from typing import Final
from pyspark.sql.functions import col, expr, window

# --- Configuration ---
# This should be the same path you used in the data generation notebook.
SOURCE_DATA_PATH: Final[str] = "/Volumes/demos/smart_factory/iot_landing"

# --- Bronze Layer: Raw Ingestion ---
# We use Auto Loader for efficient, incremental ingestion of new files.
# Schema inference and evolution are handled automatically.
@dlt.table(
    name="bronze_sensor_readings",
    comment="Raw sensor readings ingested from cloud storage."
)
def bronze_sensor_readings():
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "json")
        .option("cloudFiles.schemaLocation", SOURCE_DATA_PATH) # Auto-schema tracking
        .load(SOURCE_DATA_PATH)
        .withColumn("ingestion_timestamp", expr("from_utc_timestamp(current_timestamp(), 'America/New_York')"))
        .withColumn("source_file", expr("_metadata.file_path"))
    )

# --- Silver Layer: Cleaned & Validated Data ---
# Here we enforce data quality rules using DLT Expectations.
# Bad data can be dropped, quarantined, or allowed to flow with a warning.
@dlt.table(
    name="silver_cleaned_sensors",
    comment="Cleaned and validated sensor data with quality checks."
)
@dlt.expect_or_drop("valid_device_id", "device_id IS NOT NULL")
@dlt.expect("warn_on_high_temp", "temperature_celsius < 40") # Warn, but don't drop
def silver_cleaned_sensors():
    return (
        dlt.read_stream("bronze_sensor_readings")
        .select(
            "device_id",
            col("timestamp").cast("timestamp").alias("event_timestamp"),
            "temperature_celsius",
            "vibration_hz",
            "location",
            "ingestion_timestamp",
            "source_file"
        )
    )

# --- Quarantine Table for invalid data ---
# This table captures records that were dropped from the silver table.
# The rule here is the INVERSE of the silver table's drop rule.
@dlt.table(
    name="silver_quarantined_sensors",
    comment="Records that failed validation, e.g., missing device_id."
)
@dlt.expect_or_drop("invalid_device_id", "device_id IS NULL") # We explicitly capture the bad records
def silver_quarantined_sensors():
  return (
    dlt.read_stream("bronze_sensor_readings")
        .select(
            "device_id",
            col("timestamp").cast("timestamp").alias("event_timestamp"),
            "temperature_celsius",
            "vibration_hz",
            "location",
            "ingestion_timestamp",
            "source_file"
        )
    )

# --- Gold Layer: Business Aggregates ---
# This table provides a high-level view for analysts and business users.
@dlt.table(
    name="gold_hourly_device_summary",
    comment="Hourly aggregated sensor data per device."
)
def gold_hourly_device_summary():
    return (
        dlt.read_stream("silver_cleaned_sensors")
        # .withWatermark("event_timestamp", "2 minutes") # Handle late-arriving data
        .groupBy(
            "device_id",
            "location",
            window("event_timestamp", "30 seconds") # Tumbling window aggregation
        )
        .agg(
            expr("avg(temperature_celsius)").alias("avg_temp"),
            expr("max(temperature_celsius)").alias("max_temp"),
            expr("avg(vibration_hz)").alias("avg_vibration"),
            expr("count(*)").alias("reading_count")
        )
    )


