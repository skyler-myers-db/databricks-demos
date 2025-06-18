# The "Smart Factory" IoT Pipeline

**Narrative**: We are operating a smart factory with thousands of IoT sensors on our manufacturing equipment. These sensors stream temperature and vibration data. Our goal is to build a highly reliable, observable data pipeline that:

1. Ingests raw sensor data in real-time.
2. Cleans and validates the data, flagging quality issues.
3. Transforms the data into meaningful business-level aggregates.
4. Proactively alerts operators of equipment that is overheating, indicating a potential failure.
5. Provides dashboards for monitoring both the pipeline's health and the factory's operational status.

This narrative allows us to naturally showcase Databricks features as solutions to business problems.

## Demo Prerequisites

1. A Databricks Workspace (Premium or Enterprise) on any cloud.
2. Permissions to create clusters, run jobs, create DLT pipelines, and create DBSQL queries/alerts.
3. A location in your cloud storage (e.g., S3 bucket, ADLS gen2 container) that your Databricks workspace can access. We'll call this [YOUR_STORAGE_PATH].
4. (Optional) A notification integration for alerts (e.g., your email address, a Slack webhook).

## Part 1: The Setup - Generating our Data

**(Talk Track)**: "Every great data solution starts with data. In our Smart Factory, we have sensors constantly emitting JSON data into our cloud storage. Let's simulate that. I'll use a simple Python script right here in a Databricks notebook to generate our initial batch of sensor readings and land them in our raw data location."
