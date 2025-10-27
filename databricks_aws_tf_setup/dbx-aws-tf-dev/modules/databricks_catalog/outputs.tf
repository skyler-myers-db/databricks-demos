output "catalog_name" {
  description = "Name of the created catalog"
  value       = databricks_catalog.main.name
}

output "catalog_id" {
  description = "ID of the created catalog"
  value       = databricks_catalog.main.id
}

output "storage_credential_name" {
  description = "Name of the storage credential"
  value       = databricks_storage_credential.catalog.name
}

output "storage_credential_id" {
  description = "ID of the storage credential"
  value       = databricks_storage_credential.catalog.id
}

output "external_location_name" {
  description = "Name of the external location"
  value       = databricks_external_location.catalog.name
}

output "external_location_url" {
  description = "URL of the external location"
  value       = databricks_external_location.catalog.url
}

output "default_schema_name" {
  description = "Name of the default schema"
  value       = databricks_schema.default.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role for catalog storage access"
  value       = aws_iam_role.catalog_storage.arn
}

output "storage_credential_external_id" {
  description = "External ID from Databricks storage credential (auto-updated in IAM role)"
  value       = databricks_storage_credential.catalog.id
}

output "iam_role_trust_policy_status" {
  description = "Status of IAM role trust policy update"
  value       = "Trust policy automatically updated with storage credential external ID"
  depends_on  = [null_resource.update_iam_trust_policy]
}

output "setup_validation" {
  description = "Instructions for validating the automated setup"
  value       = <<-EOT
    ================================================================================
    AUTOMATED STORAGE CREDENTIAL SETUP - VALIDATION
    ================================================================================

    ✅ FULLY AUTOMATED - No manual steps required!

    The following was automatically configured:
    1. IAM Role created with Databricks Account ID as initial external ID
    2. Storage Credential created in Databricks
    3. IAM Role trust policy auto-updated with storage credential external ID
    4. External Location created and linked to catalog

    To validate everything is working:

    1. Check Databricks UI:
       - Go to: Catalog > External Data > Credentials
       - Select: ${databricks_storage_credential.catalog.name}
       - Click: "Validate Configuration"
       - Verify: All checks pass (especially "Self Assume Role")

    2. Test data access:
       CREATE TABLE ${var.catalog_name}.default.test (id INT);
       INSERT INTO ${var.catalog_name}.default.test VALUES (1);
       SELECT * FROM ${var.catalog_name}.default.test;

    Storage Credential: ${databricks_storage_credential.catalog.name}
    External ID (in Databricks): ${databricks_storage_credential.catalog.id}
    IAM Role ARN: ${aws_iam_role.catalog_storage.arn}
    External Location: ${databricks_external_location.catalog.url}
    ================================================================================
  EOT
  depends_on  = [time_sleep.trust_policy_propagation]
}
