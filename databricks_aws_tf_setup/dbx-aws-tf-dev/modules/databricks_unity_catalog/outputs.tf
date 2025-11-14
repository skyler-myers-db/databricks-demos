output "catalog_name" {
  description = "Name of the catalog"
  value       = databricks_catalog.main.name
}

output "catalog_id" {
  description = "ID of the catalog"
  value       = databricks_catalog.main.id
}

output "storage_root" {
  description = "Storage root URL for the catalog"
  value       = databricks_catalog.main.storage_root
}
