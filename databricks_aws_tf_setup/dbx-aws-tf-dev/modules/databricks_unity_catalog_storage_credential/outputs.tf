output "storage_credential_id" {
  description = "ID of the storage credential"
  value       = databricks_storage_credential.unity_catalog.id
}

output "storage_credential_name" {
  description = "Name of the storage credential (use this in catalogs)"
  value       = databricks_storage_credential.unity_catalog.name
}

output "external_location_name" {
  description = "Name of the root external location (use this in catalogs)"
  value       = databricks_external_location.unity_catalog_root.name
}

output "external_location_url" {
  description = "URL of the root external location"
  value       = trimsuffix(databricks_external_location.unity_catalog_root.url, "/")
}

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.unity_catalog_storage.arn
}

output "validation_status" {
  description = "Status and validation instructions"
  value       = <<-EOT
    ✅ Unity Catalog Storage Credential Created

    Storage Credential: ${databricks_storage_credential.unity_catalog.name}
    External Location: ${databricks_external_location.unity_catalog_root.name}
    S3 URL: ${databricks_external_location.unity_catalog_root.url}

    This credential can be reused across multiple catalogs!

    Validate in Databricks:
    1. Go to: Catalog > External Data > Credentials
    2. Select: ${databricks_storage_credential.unity_catalog.name}
    3. Click: "Validate Configuration"
    4. Verify: All checks pass
  EOT
}
