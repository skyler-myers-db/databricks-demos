terraform {
  required_providers {
    databricks = {
      source                = "databricks/databricks"
      configuration_aliases = [databricks.mws, databricks.ws]
    }
  }
}

# Providers:
#   databricks.mws (account level) for metastore
#   databricks.ws  (workspace level) for UC child objects

# Create Metastore and assign Workspace
resource "databricks_metastore" "this" {
  provider         = databricks.mws
  name             = "uc-${var.region}"
  storage_root     = var.metastore_storage_root
  region           = var.region
}

resource "databricks_metastore_assignment" "assign" {
  # This resource works with either provider; using account level here for clarity
  provider     = databricks.mws
  metastore_id = databricks_metastore.this.id
  workspace_id = var.workspace_id
}

# Storage Credential (IAM role) and External Location for a sample path
resource "databricks_storage_credential" "role_based" {
  provider     = databricks.ws
  name         = "sc-default"
  aws_iam_role {
    role_arn = var.cross_account_role_arn
  }
}

resource "databricks_external_location" "ext" {
  provider     = databricks.ws
  name         = "ext-default"
  url          = replace(var.metastore_storage_root, "/metastore", "/external")
  credential_name = databricks_storage_credential.role_based.id
}

# UC Catalog & Schema example
resource "databricks_catalog" "main" {
  provider = databricks.ws
  name     = "main"
  comment  = "Primary catalog"
  # storage_root optional; defaults to metastore root.
}

resource "databricks_schema" "bronze" {
  provider = databricks.ws
  name     = "bronze"
  catalog_name = databricks_catalog.main.name
  comment  = "Bronze schema"
}

# (Optional) Federation: Connection + Foreign Catalog
resource "databricks_connection" "federation" {
  provider   = databricks.ws
  count      = var.federation_example_enabled ? 1 : 0
  name       = "pg_fed"
  connection_type = var.federation_conn.type
  options = {
    host     = var.federation_conn.host
    port     = tostring(var.federation_conn.port)
    user     = var.federation_conn.user
    password = var.federation_conn.password
  }
}

resource "databricks_catalog" "foreign_pg" {
  provider       = databricks.ws
  count          = var.federation_example_enabled ? 1 : 0
  name           = "pg_catalog"
  connection_name = databricks_connection.federation[0].name
  options = {
    database = var.federation_conn.database
  }
}

# System tables enablement (recommended)
resource "databricks_system_schema" "billing" {
  provider = databricks.ws
  count    = var.enable_system_tables ? 1 : 0
  schema   = "system.billing"
}

resource "databricks_system_schema" "access" {
  provider = databricks.ws
  count    = var.enable_system_tables ? 1 : 0
  schema   = "system.access"
}

resource "databricks_system_schema" "lakeflow" {
  provider = databricks.ws
  count    = var.enable_system_tables ? 1 : 0
  schema   = "system.lakeflow"
}

output "metastore_id" { value = databricks_metastore.this.id }


# Example grants on catalog + schema
resource "databricks_grants" "catalog_main" {
  provider   = databricks.ws
  catalog    = databricks_catalog.main.name
  grant {
    principal  = "users"
    privileges = ["USE_CATALOG"]
  }
}

resource "databricks_grants" "schema_bronze" {
  provider = databricks.ws
  schema   = "${databricks_catalog.main.name}.${databricks_schema.bronze.name}"
  grant {
    principal  = "users"
    privileges = ["USE_SCHEMA","CREATE_TABLE"]
  }
}
