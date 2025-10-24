/**
 * Databricks Unity Catalog Metastore Module
 *
 * Purpose:
 * Creates a Unity Catalog metastore for organizing and governing data across
 * multiple Databricks workspaces in a region.
 *
 * Modern Best Practice (2024-2025):
 * - Create metastore WITHOUT storage_root (no metastore-level storage)
 * - Use catalog-level storage instead (MANAGED LOCATION per catalog)
 * - Use managed tables (NOT external tables) for full feature support
 *
 * Why NO Metastore Storage Root:
 * - Separation of concerns (metadata vs data)
 * - Catalog-specific storage policies
 * - Better organization (each catalog has its own S3 location)
 * - Databricks recommendation for modern deployments
 *
 * What's Stored in Metastore (Databricks-managed, in Databricks control plane):
 * - Catalog definitions
 * - Schema (database) definitions
 * - Table metadata (names, columns, types)
 * - Access control lists (permissions)
 * - Data lineage information
 *
 * What's NOT Stored in Metastore (Your S3 buckets):
 * - Actual table data (Parquet, Delta files)
 * - Catalog-level managed table data (s3://your-bucket/catalog-name/)
 *
 * Features Enabled by Managed Tables:
 * - Predictive Optimization (auto-optimize, auto-compaction)
 * - Liquid Clustering (automatic data layout optimization)
 * - Delta Lake ACID transactions
 * - Time travel
 * - VACUUM (automatic cleanup)
 *
 * Databricks Documentation:
 * https://docs.databricks.com/data-governance/unity-catalog/create-metastore.html
 *
 * Cost: $0/month (metastore metadata stored/managed by Databricks)
 */

# Create Unity Catalog metastore
resource "databricks_metastore" "this" {
  name   = var.metastore_name
  region = var.aws_region
  owner  = var.metastore_owner

  # NO storage_root specified → Modern best practice
  # This means:
  # - No default location for managed tables
  # - Each catalog must specify MANAGED LOCATION
  # - Better organization and governance
  # - Follows Databricks 2024-2025 recommendations

  # If you wanted metastore-level storage (NOT recommended):
  # storage_root = "s3://${var.metastore_bucket}/metastore"

  force_destroy = var.env == "dev" ? true : false
}

# Data access configuration for metastore (uses same credentials as workspace)
resource "databricks_metastore_data_access" "this" {
  metastore_id = databricks_metastore.this.id
  name         = var.data_access_config_name
  aws_iam_role {
    role_arn = var.iam_role_arn
  }
  is_default = true

  # Lifecycle configuration to handle API behavior
  # The Databricks API may not honor is_default = true in all cases
  # (e.g., if there's already a default, or if it's not supported for metastore data access)
  # Ignore changes to prevent perpetual diff
  lifecycle {
    ignore_changes = [
      is_default,
      owner,
      isolation_mode
    ]
  }
}

# Outputs
output "metastore_id" {
  description = "ID of the Unity Catalog metastore"
  value       = databricks_metastore.this.id
}

output "metastore_name" {
  description = "Name of the Unity Catalog metastore"
  value       = databricks_metastore.this.name
}

output "metastore_region" {
  description = "AWS region of the metastore"
  value       = databricks_metastore.this.region
}

output "metastore_owner" {
  description = "Owner of the metastore"
  value       = databricks_metastore.this.owner
}

output "data_access_config_id" {
  description = "ID of the data access configuration"
  value       = databricks_metastore_data_access.this.id
}

# Configuration status
output "configuration_status" {
  description = "Module configuration status and next steps"
  value = {
    step_completed = "Unity Catalog Metastore Created"
    metastore_info = {
      id     = databricks_metastore.this.id
      name   = databricks_metastore.this.name
      region = var.aws_region
      owner  = var.metastore_owner
    }
    storage_model = {
      metastore_storage = "NONE (no storage_root - modern best practice)"
      catalog_storage   = "Catalog-level MANAGED LOCATION (recommended)"
      table_type        = "Managed tables with predictive optimization"
      data_location     = "Your S3 buckets (per catalog)"
    }
    metadata_storage = {
      location        = "Databricks control plane (Databricks-managed database)"
      cost            = "$0/month (Databricks pays)"
      what_stored     = "Catalogs, schemas, table metadata, permissions, lineage"
      what_not_stored = "Actual table data (stored in your S3 buckets)"
    }
    next_steps = [
      "Assign metastore to workspace during workspace creation",
      "Create catalogs with MANAGED LOCATION 's3://your-bucket/catalog-name/'",
      "Create managed tables (NOT external) for full feature support",
      "Enable predictive optimization for auto-compaction"
    ]
  }
}

# Best practices guide
output "best_practices" {
  description = "Unity Catalog best practices for this metastore"
  value = {
    catalog_creation = {
      recommended = "CREATE CATALOG sales MANAGED LOCATION 's3://your-data-bucket/catalogs/sales/'"
      avoid       = "CREATE CATALOG sales (no location - would use metastore root if it existed)"
      reasoning   = "Catalog-level storage gives you control, organization, and flexibility"
    }
    table_creation = {
      recommended = "CREATE TABLE catalog.schema.table (...) - Managed table"
      avoid       = "CREATE TABLE ... LOCATION 's3://...' - External table"
      reasoning   = "Managed tables get predictive optimization, liquid clustering, auto-VACUUM"
    }
    feature_enablement = [
      "ALTER TABLE SET TBLPROPERTIES ('delta.autoOptimize.optimizeWrite' = 'true')",
      "ALTER TABLE SET TBLPROPERTIES ('delta.autoOptimize.autoCompact' = 'true')",
      "Enable predictive optimization in workspace settings"
    ]
  }
}

# Cost analysis
output "cost_estimate" {
  description = "Monthly cost estimate for Unity Catalog metastore"
  value = {
    metastore_metadata   = "$0.00/month (Databricks pays for metadata storage)"
    data_access_config   = "$0.00/month (IAM configuration, no cost)"
    catalog_data_storage = "Variable (~$0.023/GB/month S3 Standard in your buckets)"
    total_monthly        = "$0.00/month (metastore infrastructure)"
    notes                = "Metastore metadata is stored in Databricks control plane at no cost to you. You pay only for your S3 data storage."
  }
}
