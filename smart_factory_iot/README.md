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

Run the code in `src/data_generation.ipynb`

## Part 2: The "Happy Path" - Building a Resilient Pipeline with Delta Live Tables

**(Talk Track)**: "Now that we have data, we need to process it. We'll use Delta Live Tables (DLT), Databricks' framework for building reliable, maintainable, and testable data pipelines. DLT allows us to define our pipeline declaratively in SQL or Python and handles all the complex operational overhead for us."

**Action**:

1. Go to the Workflows tab in Databricks, select Delta Live Tables, and click Create Pipeline.
2. Configure the pipeline:
  * **Pipeline Name**: `Smart_Factory_Pipeline`
  * **Pipeline mode**: `Triggered`
  * **Source Code**: Use the `dlt_pipeline.py` file
  * **Target schema**: `smart_factory` (This is where the final tables will be published).
3. Click Create. Do not run it yet.

**(Talk Track & Action)**:

1. **(Point to the DLT code)**: "Here we define our pipeline in three stages: Bronze, Silver, and Gold.
  * The Bronze table uses Auto Loader to incrementally pull new JSON files from our landing zone. It automatically infers the schema.
  * The Silver table is where we enforce quality. Notice the `@dlt.expect` rules. We're ensuring every record has a `device_id`, and we're flagging records with temperatures over 40 degrees. This is data quality built directly into the pipeline.
  * The Gold table creates a business-level aggregate: the hourly average and max temperature for each device. This is what our analysts will use."
2. **(Start the pipeline)**: Now, click the Start button on the DLT pipeline UI.
3. **(Explain the DLT Graph)**: As it runs, a graph will appear. "This is one of the key monitoring features of DLT. You get a real-time, visual DAG of your pipeline. We can see the data flowing from Bronze to Silver to Gold. If I click on a table, I can see the record counts and, importantly, the data quality metrics from the expectations we defined."

## Part 3: Demonstrating Fault Tolerance

**(Talk Track)**: "Now for the critical part: what happens when things go wrong? A production pipeline must be fault-tolerant. Let's simulate two common issues: late-arriving data and schema changes."

**Action 1: Simulate New Data (Demonstrates Checkpointing)**

1. Run the original data generation notebook again
   
**(Talk Track)**: "I've just dropped new files into our landing zone. Because this is a Triggered pipeline, it's not running right now. But DLT uses checkpointing to keep track of exactly which files it has processed. The next time the pipeline runs, it will automatically pick up only the new files, guaranteeing exactly-once processing without any manual intervention."

**Action 2: Simulate a Schema Change (Demonstrates Schema Evolution)**

1. Run the `data_generation_schema_change.py` file to generate a few more batches. This new data now has the `humidity_percent` field.

**(Talk Track & Action):**

1. "A data team's nightmare is an upstream schema change breaking the pipeline. Let's add a new humidity field to our source data and see what happens."
2. Go back to the DLT Pipeline UI and click Start again.
3. "Watch the pipeline graph. Auto Loader, which we configured in our Bronze table, detects this new column. It seamlessly evolves the schema of the table without failing the pipeline. The new humidity_percent column will now flow through to our Bronze table. This automatic schema evolution is a massive feature for operational stability."

## Part 4: Monitoring & Alerting

**(Talk Track)**: "Fault tolerance is about automatic recovery. Monitoring and alerting are about proactive awareness. Databricks provides tools for every persona, from engineers to analysts."

**Action 1: Monitoring with Dashboards (for the Analyst)**

1. Go to the `sensor_analysis` notebook
2. Run the first query
3. Create a bar chart
4. Save the bar chart to a notebook dashboard and a real dashboard named "Smart Factory Operations"

**(Talk Track)**: "Using Databricks SQL, our analysts can immediately query the clean, aggregated data from our pipeline. They can build powerful, auto-refreshing dashboards like this one to monitor the factory floor in near real-time."

**Action 2: Alerting on Business KPIs (for the Operator)**

1. Take the second query to find overheating devices and save it in the Databricks SQL Editor
2. Click the "Create Alert" button above the query editor.
3. Configure the alert:
  * **Trigger when**: value column is > 0 (meaning the query returned at least one hot device).
  * **Name**: Overheating Equipment Alert
  * **Notifications**: Select your email address or another pre-configured destination. Set it to refresh every 2 minutes.

**(Talk Track)**: "Dashboards are great for passive monitoring, but we need proactive alerts. Here, we've created an alert directly from our SQL query. If any device's max temperature exceeds 40 degrees, this alert will trigger and automatically send an email to the factory operator. This closes the loop from data ingestion to actionable insight."

**Action 3: Trigger the Alert**

1. Run the `data_generation_trigger_event.py` file
2. Run your DLT pipeline one more time to process the hot data into the Gold table.
3. Within a few minutes, the DBSQL Alert will run, find the hot data, and send a notification. (You can show the alert turning "Red" in the UI).

## Part 5: Conclusion

**(Talk Track)**: "So, let's recap what we've built in just a few minutes, demonstrating Entrada's approach to modern data solutions:

1. **Automated Ingestion**: We used Auto Loader to build a self-managing ingestion process that handles backlogs and schema changes.
2. **Declarative & Reliable ETL**: We defined our entire pipeline with Delta Live Tables, building in data quality and making it observable and fault-tolerant by design.
3. **Monitoring for All**: We saw the DLT graph for engineers, and we built a Databricks SQL dashboard for business analysts.
4. **Proactive Alerting**: We created a real-time alert that turns data into a direct, automated action, preventing equipment failure before it happens.

This pattern—Auto Loader + DLT + DBSQL Dashboards & Alerts—is a best-practice, scalable architecture that we at Entrada deploy for our clients. It leverages the latest and most powerful Databricks features to deliver solutions that are not only powerful but also robust, maintainable, and drive real business value."
