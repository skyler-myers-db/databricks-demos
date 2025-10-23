/**
 * Databricks IAM Policy Module - Input Variables
 *
 * Required for attaching comprehensive S3, KMS, STS, and file events policies
 * to Databricks IAM role per Step 3 of Databricks Unity Catalog setup
 */

variable "policy_name" {
  description = "Name of the IAM policy for S3 bucket access"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]+$", var.policy_name))
    error_message = "Policy name must contain only alphanumeric characters and +=,.@_-"
  }
}

variable "role_name" {
  description = "Name of the IAM role to attach policy to (from databricks_iam_role module)"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the S3 bucket to grant access to (from databricks_s3_root_bucket module)"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:s3:::[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_arn))
    error_message = "Bucket ARN must be a valid S3 ARN format."
  }
}

variable "bucket_name" {
  description = "Name of the S3 bucket (for tagging and documentation)"
  type        = string
}

variable "workspace_name" {
  description = "Name of the Databricks workspace (for tagging purposes)"
  type        = string
}

variable "project_name" {
  description = "Project name (for consistent naming and tagging)"
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

variable "kms_key_arn" {
  description = "ARN of KMS key used for bucket encryption (optional - set to null if using SSE-S3)"
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$", var.kms_key_arn))
    error_message = "KMS key ARN must be a valid ARN format or null."
  }
}

variable "enable_file_events" {
  description = "Enable file events management policy for S3 notifications, SNS, and SQS (highly recommended by Databricks)"
  type        = bool
  default     = true
}
