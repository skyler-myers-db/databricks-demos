import json
import random
import time
from datetime import datetime, timedelta
from typing import Final, List
from loguru import logger
import pytz

dbutils.widgets.text(
    "landing_dir",
    "/Volumes/demos/smart_factory/iot_landing",
    "Volume where the IoT landing data will be written to",
)

LANDING_ZONE_PATH: Final[str] = dbutils.widgets.get("landing_dir")
logger.info(f"Landing directory set to: '{LANDING_ZONE_PATH}'")

PARTS: Final[List[str]] = LANDING_ZONE_PATH.split("/")

CAT: Final[str] = PARTS[2]
S: Final[str] = PARTS[3]
VOL: Final[str] = PARTS[4]

display(spark.sql("CREATE CATALOG IF NOT EXISTS IDENTIFIER(:cat);", args={"cat": CAT}))
display(
    spark.sql(
        "CREATE SCHEMA IF NOT EXISTS IDENTIFIER(:cat || '.' || :s);",
        args={"cat": CAT, "s": S},
    )
)

display(
    spark.sql(
        "CREATE VOLUME IF NOT EXISTS IDENTIFIER(:cat || '.' || :s || '.' ||:vol);",
        args={"cat": CAT, "s": S, "vol": VOL},
    )
)

device_ids = [f"MFG-A-{1000+i}" for i in range(10)] + [
    f"MFG-B-{2000+i}" for i in range(5)
]


def generate_sensor_reading(device_id):
    """Generates a single sensor reading."""
    # 95% of data is normal
    if random.random() < 0.95:
        temp = round(random.uniform(25.0, 35.0), 2)
        vibration = round(random.uniform(0.1, 0.5), 4)
    # 5% of data is anomalous (potential issue)
    else:
        temp = round(random.uniform(40.0, 45.0), 2)
        vibration = round(random.uniform(0.5, 1.2), 4)

    utc_time = datetime.utcnow() - timedelta(seconds=random.randint(0, 60))
    est_time = utc_time.replace(tzinfo=pytz.utc).astimezone(pytz.timezone("US/Eastern"))

    return {
        "device_id": device_id,
        "timestamp": est_time.isoformat(),
        "temperature_celsius": temp,
        "vibration_hz": vibration,
        "humidity_percent": round(random.uniform(30.0, 50.0), 1),  # NEW FIELD
        "location": "Factory Floor A" if "MFG-A" in device_id else "Factory Floor B",
    }


def generate_and_save_batch(batch_size=100):
    """Generates a batch of data and saves it as a single JSON file."""
    data = [
        generate_sensor_reading(random.choice(device_ids)) for _ in range(batch_size)
    ]
    file_name = f"sensor-batch-{int(time.time())}.json"
    file_path = f"{LANDING_ZONE_PATH.rstrip('/')}/{file_name}"

    with open(file_path, "w") as f:
        json.dump(data, f)
    logger.info(
        f"Generated batch of {len(data)} records to: {LANDING_ZONE_PATH}{file_name}"
    )


logger.info(f"Generating data in: {LANDING_ZONE_PATH}")
logger.info("-" * 30)
for i in range(5):
    generate_and_save_batch()
    time.sleep(1)

logger.info("-" * 30)
logger.info("Listing files in landing zone:")
display(dbutils.fs.ls(LANDING_ZONE_PATH))