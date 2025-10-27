/**
 * Databricks Cluster Policies Module
 *
 * Purpose:
 * Creates intelligent cluster policies for different user personas in sandbox environment.
 * Balances broad permissions (sandbox requirement) with cost control and security.
 *
 * Policies:
 * 1. Data Engineering Policy - Broad permissions for data engineers
 * 2. Analyst Policy - Restricted compute, read-optimized
 * 3. Admin Policy - Unrestricted for workspace admins
 *
 * Sandbox Environment:
 * - Liberal instance types and sizes
 * - Autoscaling enabled
 * - Auto-termination enforced (cost control)
 * - Unity Catalog enabled by default
 * - Spot instances allowed (cost savings)
 *
 * Cost Control:
 * - Auto-termination: 30-120 minutes idle
 * - Autoscaling limits prevent runaway costs
 * - Spot instances reduce compute costs by 70%
 *
 * Databricks Documentation:
 * https://docs.databricks.com/administration-guide/clusters/policies.html
 */

# ============================================================================
# DATA ENGINEERING CLUSTER POLICY - Broad Permissions
# ============================================================================
# For data engineers building pipelines, ETL jobs, experimentation
# Liberal but with cost guardrails

resource "databricks_cluster_policy" "data_engineering" {
  name = "${var.workspace_name}-data-engineering-policy"

  definition = jsonencode({
    "spark_version" : {
      "type" : "unlimited",
      "defaultValue" : "auto:latest-lts"
    },
    "node_type_id" : {
      "type" : "allowlist",
      "values" : var.allowed_instance_types,
      "defaultValue" : var.default_instance_type
    },
    "driver_node_type_id" : {
      "type" : "allowlist",
      "values" : var.allowed_instance_types,
      "defaultValue" : var.default_instance_type
    },
    "num_workers" : {
      "type" : "range",
      "minValue" : 1,
      "maxValue" : 10,
      "defaultValue" : 2
    },
    "autoscale.min_workers" : {
      "type" : "range",
      "minValue" : 1,
      "maxValue" : 5,
      "defaultValue" : 1
    },
    "autoscale.max_workers" : {
      "type" : "range",
      "minValue" : 2,
      "maxValue" : 20,
      "defaultValue" : 8
    },
    "autotermination_minutes" : {
      "type" : "range",
      "minValue" : 10,
      "maxValue" : 40,
      "defaultValue" : 20,
      "hidden" : false
    },
    "enable_elastic_disk" : {
      "type" : "fixed",
      "value" : true
    },
    "data_security_mode" : {
      "type" : "allowlist",
      "values" : ["USER_ISOLATION", "SINGLE_USER"],
      "defaultValue" : "USER_ISOLATION"
    },
    "runtime_engine" : {
      "type" : "allowlist",
      "values" : ["STANDARD", "PHOTON"],
      "defaultValue" : "PHOTON"
    },
    "spark_conf.spark.databricks.cluster.profile" : {
      "type" : "fixed",
      "value" : "singleNode",
      "hidden" : true
    },
    "custom_tags.Environment" : {
      "type" : "fixed",
      "value" : var.env
    },
    "custom_tags.Team" : {
      "type" : "fixed",
      "value" : "data-engineering"
    },
    "custom_tags.CostCenter" : {
      "type" : "fixed",
      "value" : var.cost_center
    },
    "aws_attributes.availability" : {
      "type" : "allowlist",
      "values" : ["SPOT_WITH_FALLBACK", "ON_DEMAND", "SPOT"],
      "defaultValue" : "SPOT_WITH_FALLBACK"
    },
    "aws_attributes.zone_id" : {
      "type" : "unlimited",
      "defaultValue" : "auto"
    },
    "aws_attributes.first_on_demand" : {
      "type" : "range",
      "minValue" : 0,
      "maxValue" : 5,
      "defaultValue" : 1
    },
    "aws_attributes.spot_bid_price_percent" : {
      "type" : "range",
      "minValue" : 50,
      "maxValue" : 100,
      "defaultValue" : 100
    }
  })

  description = "Cluster policy for data engineers - broad permissions with cost guardrails"

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# ANALYST CLUSTER POLICY - Cost-Optimized, Read-Heavy
# ============================================================================
# For analysts running queries, creating visualizations, data exploration
# Smaller clusters, shorter auto-termination, read-optimized

resource "databricks_cluster_policy" "analyst" {
  name = "${var.workspace_name}-analyst-policy"

  definition = jsonencode({
    "spark_version" : {
      "type" : "unlimited",
      "defaultValue" : "auto:latest-lts"
    },
    "node_type_id" : {
      "type" : "allowlist",
      "values" : var.analyst_instance_types,
      "defaultValue" : var.analyst_default_instance_type
    },
    "driver_node_type_id" : {
      "type" : "allowlist",
      "values" : var.analyst_instance_types,
      "defaultValue" : var.analyst_default_instance_type
    },
    "num_workers" : {
      "type" : "range",
      "minValue" : 0,
      "maxValue" : 4,
      "defaultValue" : 1
    },
    "autoscale.min_workers" : {
      "type" : "range",
      "minValue" : 0,
      "maxValue" : 2,
      "defaultValue" : 1
    },
    "autoscale.max_workers" : {
      "type" : "range",
      "minValue" : 1,
      "maxValue" : 8,
      "defaultValue" : 4
    },
    "autotermination_minutes" : {
      "type" : "range",
      "minValue" : 10,
      "maxValue" : 30,
      "defaultValue" : 30,
      "hidden" : false
    },
    "enable_elastic_disk" : {
      "type" : "fixed",
      "value" : true
    },
    "data_security_mode" : {
      "type" : "fixed",
      "value" : "SINGLE_USER"
    },
    "runtime_engine" : {
      "type" : "fixed",
      "value" : "PHOTON"
    },
    "custom_tags.Environment" : {
      "type" : "fixed",
      "value" : var.env
    },
    "custom_tags.Team" : {
      "type" : "fixed",
      "value" : "analytics"
    },
    "custom_tags.CostCenter" : {
      "type" : "fixed",
      "value" : var.cost_center
    },
    "aws_attributes.availability" : {
      "type" : "fixed",
      "value" : "SPOT_WITH_FALLBACK"
    },
    "aws_attributes.first_on_demand" : {
      "type" : "fixed",
      "value" : 1
    },
    "aws_attributes.spot_bid_price_percent" : {
      "type" : "fixed",
      "value" : 100
    }
  })

  description = "Cluster policy for analysts - cost-optimized, read-heavy workloads, smaller clusters"

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# ADMIN CLUSTER POLICY - Unrestricted
# ============================================================================
# For workspace admins - full control for troubleshooting and special cases

resource "databricks_cluster_policy" "admin" {
  name = "${var.workspace_name}-admin-policy"

  definition = jsonencode({
    "spark_version" : {
      "type" : "unlimited",
      "defaultValue" : "auto:latest-lts"
    },
    "node_type_id" : {
      "type" : "unlimited",
      "defaultValue" : var.default_instance_type
    },
    "driver_node_type_id" : {
      "type" : "unlimited",
      "defaultValue" : var.default_instance_type
    },
    "num_workers" : {
      "type" : "unlimited",
      "defaultValue" : 2
    },
    "autoscale.min_workers" : {
      "type" : "unlimited",
      "defaultValue" : 1
    },
    "autoscale.max_workers" : {
      "type" : "unlimited",
      "defaultValue" : 10
    },
    "autotermination_minutes" : {
      "type" : "range",
      "minValue" : 10,
      "maxValue" : 60,
      "defaultValue" : 60,
      "hidden" : false
    },
    "enable_elastic_disk" : {
      "type" : "unlimited",
      "defaultValue" : true
    },
    "data_security_mode" : {
      "type" : "unlimited",
      "defaultValue" : "USER_ISOLATION"
    },
    "runtime_engine" : {
      "type" : "unlimited",
      "defaultValue" : "PHOTON"
    },
    "custom_tags.Environment" : {
      "type" : "fixed",
      "value" : var.env
    },
    "custom_tags.Team" : {
      "type" : "fixed",
      "value" : "admin"
    },
    "custom_tags.CostCenter" : {
      "type" : "fixed",
      "value" : var.cost_center
    }
  })

  description = "Cluster policy for admins - unrestricted access for troubleshooting and special cases"

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "data_engineering_policy_id" {
  description = "ID of the data engineering cluster policy"
  value       = databricks_cluster_policy.data_engineering.id
}

output "data_engineering_policy_name" {
  description = "Name of the data engineering cluster policy"
  value       = databricks_cluster_policy.data_engineering.name
}

output "analyst_policy_id" {
  description = "ID of the analyst cluster policy"
  value       = databricks_cluster_policy.analyst.id
}

output "analyst_policy_name" {
  description = "Name of the analyst cluster policy"
  value       = databricks_cluster_policy.analyst.name
}

output "admin_policy_id" {
  description = "ID of the admin cluster policy"
  value       = databricks_cluster_policy.admin.id
}

output "admin_policy_name" {
  description = "Name of the admin cluster policy"
  value       = databricks_cluster_policy.admin.name
}

output "policy_summary" {
  description = "Summary of cluster policies"
  value = {
    data_engineering = {
      id          = databricks_cluster_policy.data_engineering.id
      name        = databricks_cluster_policy.data_engineering.name
      max_workers = 20
      auto_term   = "10-40 minutes"
      use_case    = "ETL pipelines, data engineering, experimentation"
    }
    analyst = {
      id          = databricks_cluster_policy.analyst.id
      name        = databricks_cluster_policy.analyst.name
      max_workers = 8
      auto_term   = "10-30 minutes"
      use_case    = "SQL queries, visualizations, data exploration"
    }
    admin = {
      id          = databricks_cluster_policy.admin.id
      name        = databricks_cluster_policy.admin.name
      max_workers = "unlimited"
      auto_term   = "10-60 minutes"
      use_case    = "Admin operations, troubleshooting, special cases"
    }
  }
}
