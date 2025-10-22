terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}

# Example cluster policy and a small instance pool to demonstrate dependencies

# Minimal instance pool
# resource "databricks_instance_pool" "small" {
#   instance_pool_name          = "pool-small"
#   min_idle_instances          = 0
#   max_capacity                = 10
#   node_type_id                = "i3.xlarge"
#   idle_instance_autotermination_minutes = 15
# }

# Cluster policy that forces UC compliant access mode
resource "databricks_cluster_policy" "uc_restricted" {
  name = "uc-restricted"

  definition = jsonencode({
    spark_conf = {
      hidden = false
      type = "fixed"
      value = {
        "spark.databricks.repl.allowedLanguages" : "python,sql"
      }
    }
    data_security_mode = {
      type = "fixed"
      value = "SINGLE_USER"
    }
  })
}

# Workspace permissions example: allow admin group to manage the policy
resource "databricks_permissions" "policy_perms" {
  cluster_policy_id = databricks_cluster_policy.uc_restricted.id
  access_control {
    group_name       = var.admin_group
    permission_level = "CAN_MANAGE"
  }
}


# Example group & entitlements (workspace level)
resource "databricks_group" "data_engineers" {
  display_name = "data-engineers"
}

resource "databricks_entitlements" "data_engineers" {
  group_id = databricks_group.data_engineers.id
  allow_cluster_create     = true
  databricks_sql_access    = true
  workspace_access         = true
}
