/**
 * Databricks Storage Configuration Module - Input Variables
 *
 * Required for creating Databricks account-level storage configuration
 */

variable "databricks_account_id" {
  description = "Databricks account ID (UUID format)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", var.databricks_account_id))
    error_message = "Databricks account ID must be a valid UUID format."
  }
}

variable "storage_configuration_name" {
  description = "Human-readable name for the storage configuration (visible in Databricks UI)"
  type        = string

  validation {
    condition     = length(var.storage_configuration_name) >= 3 && length(var.storage_configuration_name) <= 255
    error_message = "Storage configuration name must be between 3 and 255 characters."
  }
}

variable "credentials_name" {
  description = "Human-readable name for the credentials configuration (visible in Databricks UI)"
  type        = string

  validation {
    condition     = length(var.credentials_name) >= 3 && length(var.credentials_name) <= 255
    error_message = "Credentials name must be between 3 and 255 characters."
  }
}

variable "bucket_name" {
  description = "Name of the S3 bucket for workspace storage (from databricks_s3_root_bucket module)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be valid S3 bucket name format."
  }
}

variable "role_arn" {
  description = "ARN of the IAM role for Databricks access (from databricks_iam_role module)"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/", var.role_arn))
    error_message = "Role ARN must be a valid IAM role ARN format."
  }
}

variable "project_name" {
  description = "Project name (for consistent naming)"
  type        = string
}

variable "env" {
  description = "Environment (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}
