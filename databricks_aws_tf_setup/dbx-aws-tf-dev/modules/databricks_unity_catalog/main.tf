# ============================================================================
# UNITY CATALOG MODULE
# ============================================================================
# Purpose: Creates a Unity Catalog catalog with managed storage
# Note: Requires external location/storage credential to be created separately
# ============================================================================

resource "databricks_catalog" "main" {
  provider     = databricks
  metastore_id = var.metastore_id
  name         = var.catalog_name
  comment      = "Unity Catalog for ${var.project_name} ${var.env} - ${var.catalog_name}"

  storage_root = var.storage_root_url

  properties = {
    purpose     = "production"
    managed_by  = "terraform"
    environment = var.env
    project     = var.project_name
  }
}

# ============================================================================
# DEFAULT SCHEMA -- you should use DABs for this though
# ============================================================================
# resource "databricks_schema" "default" {
#   provider     = databricks
#   catalog_name = databricks_catalog.main.name
#   name         = "default"
#   comment      = "Default schema for ${var.catalog_name} catalog"

#   properties = {
#     created_by = "terraform"
#   }
# }
