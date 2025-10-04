import dbldatagen as dg
from pyspark import pipelines as dp
from pyspark.sql.functions import current_timestamp, from_utc_timestamp, col


@dp.table(
    name="raw_customer_details",
    comment="Customer details data including email, IP, and phone number.",
    table_properties={
        "demo": "api",
        "developer": "skyler",
        "delta.autoOptimize.autoCompact": "true",
        "delta.autoOptimize.optimizeWrite": "true",
        "delta.checkpointPolicy": "v2",
        "delta.dataSkippingNumIndexedCols": "-1",
        "delta.enableTypeWidening": "true",
        "delta.enableChangeDataFeed": "true",
    },
    spark_conf={"spark.sql.shuffle.partitions": "auto"},
    cluster_by_auto=True,
)
@dp.expect_or_fail(name="null_id", inv="customer_id IS NOT NULL")
def data_generation():
    return (
        dg.Datasets(spark, "basic/user")
        .get(rows=1_000_000)
        .build()
        .withColumns(
            {
                "_created_ts": from_utc_timestamp(
                    current_timestamp(),
                    "America/New_York",
                ),
            }
        )
    )


dp.create_streaming_table(
    name="customer_details_history",
    comment="Deduped customer details with CDC",
    table_properties={
        "demo": "api",
        "developer": "skyler",
        "delta.autoOptimize.autoCompact": "true",
        "delta.autoOptimize.optimizeWrite": "true",
        "delta.checkpointPolicy": "v2",
        "delta.dataSkippingNumIndexedCols": "-1",
        "delta.enableTypeWidening": "true",
        "delta.enableChangeDataFeed": "true",
    },
    spark_conf={"spark.sql.shuffle.partitions": "auto"},
    cluster_by_auto=True,
    expect_all_or_drop={"valid_customer": "customer_id IS NOT NULL"},
)

dp.create_auto_cdc_flow(
    target="customer_details_history",
    source="raw_customer_details",
    keys=["customer_id"],
    sequence_by=col("_created_ts"),
    ignore_null_updates=False,
    except_column_list=["_created_ts"],
    stored_as_scd_type="2",
)


@dp.table(
    name="customer_details",
    comment="Most recent customer details",
    table_properties={
        "demo": "api",
        "developer": "skyler",
        "delta.autoOptimize.autoCompact": "true",
        "delta.autoOptimize.optimizeWrite": "true",
        "delta.checkpointPolicy": "v2",
        "delta.dataSkippingNumIndexedCols": "-1",
        "delta.enableTypeWidening": "true",
    },
    spark_conf={"spark.sql.shuffle.partitions": "auto"},
    cluster_by_auto=True,
)
@dp.expect(name="valid_email", inv="email IS NOT NULL")
def final_customers():
    return (
        dp.read_stream("customer_details_history")
        .filter(col("__END_AT").isNull())
        .drop(col("__END_AT"))
        .withColumnRenamed("__START_AT", "modified_ts")
    )
