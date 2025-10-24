/**
 * Databricks Storage Configuration Module (Step 4)
 *
 * Purpose:
 * Registers S3 bucket and IAM role with Databricks account for workspace creation.
 * This creates a storage configuration that can be referenced during workspace provisioning.
 *
 * Prerequisites (must be completed):
 * - Step 1: S3 bucket created with proper bucket policy
 * - Step 2: IAM role created with Databricks trust policy
 * - Step 3: IAM policies attached (S3, KMS, STS, file events)
 *
 * Databricks API/Provider Details:
 * - Resource: databricks_mws_storage_configurations
 * - Scope: Account-level configuration
 * - Purpose: Associates AWS resources with Databricks account
 *
 * Databricks Documentation:
 * https://docs.databricks.com/administration-guide/account-settings/storage.html
 *
 * Cost: $0/month (configuration metadata only, no infrastructure costs)
 */

# Databricks storage configuration resource
resource "databricks_mws_storage_configurations" "this" {
  account_id                 = var.databricks_account_id
  storage_configuration_name = var.storage_configuration_name
  bucket_name                = var.bucket_name

  # Storage configuration metadata
  # This tells Databricks account which S3 bucket to use for workspace storage
}

# Create credential configuration that references the IAM role
resource "databricks_mws_credentials" "this" {
  credentials_name = var.credentials_name
  role_arn         = var.role_arn

  # Credentials metadata
  # This tells Databricks account which IAM role to assume for S3 access
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
    step_completed = "Step 4: Storage Configuration Created"
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
    next_step  = "Step 5: Create Databricks network configuration"
    required_info = {
      vpc_id            = "From aws_vpc module output"
      subnet_ids        = "From aws_subnets module output (private subnets)"
      security_group_id = "From aws_security_groups module output (workspace SG)"
    }
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
