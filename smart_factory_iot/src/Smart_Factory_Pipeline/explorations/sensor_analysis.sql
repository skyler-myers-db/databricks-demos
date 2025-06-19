-- Databricks notebook source
SELECT location, AVG(avg_temp)
FROM demos.smart_factory.gold_hourly_device_summary
GROUP BY ALL

-- COMMAND ----------

-- This query identifies devices with a recent max temperature over 40
SELECT
  device_id,
  window.start as hour,
  max_temp
FROM demos.smart_factory.gold_hourly_device_summary
WHERE max_temp >= 40.0
AND window.start >= now() - INTERVAL '3' HOUR -- check last 3 hours
