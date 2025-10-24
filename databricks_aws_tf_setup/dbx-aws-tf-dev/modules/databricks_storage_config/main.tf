/**
 * Databricks Storage Configuration Module
 *
 * Purpose:
 * Creates TWO account-level configurations required for workspace deployment:
 * 1. Storage Configuration - Links S3 bucket to Databricks account
 * 2. Credentials Configuration - Links IAM role to Databricks account (for EC2 provisioning)
 *
 * These correspond to:
 * - "Create a storage configuration" (Databricks docs Step 1-4)
 * - "Create a credential configuration" (Databricks docs Step 1-3)
 *
 * Prerequisites (must be completed):
 * - S3 bucket created with proper bucket policy
 * - IAM role created with Databricks trust policy (arn:aws:iam::414351767826:root)
 * - IAM policies attached (Unity Catalog S3/KMS/STS + Cross-account EC2 + File Events)
 *
 * Note: Both resources use the SAME IAM role, which has permissions for:
 * - Unity Catalog storage access (S3, KMS)
 * - Workspace compute provisioning (EC2)
 *
 *
 * Cost: $0/month (configuration metadata only, no infrastructure costs)
 */

# Databricks storage configuration resource
# Links S3 bucket to Databricks account for workspace storage (DBFS root)
resource "databricks_mws_storage_configurations" "this" {
  account_id                 = var.databricks_account_id
  storage_configuration_name = var.storage_configuration_name
  bucket_name                = var.bucket_name
}

# Databricks credential configuration resource
# Links IAM role to Databricks account for EC2 compute provisioning
resource "databricks_mws_credentials" "this" {
  credentials_name = var.credentials_name
  role_arn         = var.role_arn
}

# Outputs
output "storage_configuration_id" {
  description = "ID of the storage configuration (use in workspace creation)"
  value       = databricks_mws_storage_configurations.this.storage_configuration_id
}

output "credentials_id" {
  description = "ID of the credentials configuration (use in workspace creation)"
  value       = databricks_mws_credentials.this.credentials_id
}

output "storage_configuration_name" {
  description = "Name of the storage configuration"
  value       = databricks_mws_storage_configurations.this.storage_configuration_name
}

output "credentials_name" {
  description = "Name of the credentials configuration"
  value       = databricks_mws_credentials.this.credentials_name
}

# Configuration status
output "configuration_status" {
  description = "Module configuration status and next steps"
  value = {
    step_completed = "Storage & Credentials Configurations Created"
    configurations = {
      storage = {
        id     = databricks_mws_storage_configurations.this.storage_configuration_id
        name   = databricks_mws_storage_configurations.this.storage_configuration_name
        bucket = var.bucket_name
      }
      credentials = {
        id       = databricks_mws_credentials.this.credentials_id
        name     = databricks_mws_credentials.this.credentials_name
        role_arn = var.role_arn
      }
    }
    account_id = var.databricks_account_id
    next_step  = "Create Databricks workspace with these configurations"
  }
}

# Cost analysis
output "cost_estimate" {
  description = "Monthly cost estimate for storage configuration"
  value = {
    configuration_cost = "$0.00/month (metadata only, no infrastructure)"
    storage_cost       = "~$0.023/GB/month (S3 Standard, see S3 bucket module for details)"
    data_transfer      = "Variable based on usage (S3 → Databricks clusters)"
    total_monthly      = "$0.00/month (configuration metadata)"
    notes              = "Storage configuration is free. Actual S3 storage and data transfer costs are billed based on usage."
  }
}
