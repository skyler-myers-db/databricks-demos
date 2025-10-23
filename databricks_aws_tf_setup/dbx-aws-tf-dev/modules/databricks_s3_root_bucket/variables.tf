variable "bucket_name_prefix" {
  type        = string
  default     = "databricks-workspace"
  description = "Prefix for the S3 bucket name. Final name: prefix-project-env"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.bucket_name_prefix))
    error_message = "Bucket name prefix must contain only lowercase letters, numbers, and hyphens."
  }

  validation {
    condition     = length(var.bucket_name_prefix) <= 30
    error_message = "Bucket name prefix must be 30 characters or less to allow for project and env suffixes."
  }
}

variable "project_name" {
  type        = string
  description = "Name of the project, used in bucket naming and tagging."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "env" {
  type        = string
  description = "Environment name (dev, staging, prod). Used in bucket naming and tagging."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "workspace_name" {
  type        = string
  description = "Databricks workspace name (for tagging and documentation)."
}

variable "dbx_account_id" {
  type        = string
  description = "Your Databricks account ID (E2 format, e.g., 'a1b2c3d4-e5f6-7890-abcd-ef1234567890')."

  validation {
    condition     = can(regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", var.dbx_account_id))
    error_message = "Databricks account ID must be in UUID format (e.g., 'a1b2c3d4-e5f6-7890-abcd-ef1234567890')."
  }
}

variable "log_retention_days" {
  type        = number
  default     = 365
  description = "Number of days to retain cluster logs before deletion (lifecycle policy)."

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 3650
    error_message = "Log retention must be between 30 and 3650 days."
  }
}

# ============================================================================
# OPTIONAL VARIABLES (Uncomment and configure as needed)
# ============================================================================

# variable "kms_key_id" {
#   type        = string
#   default     = null
#   description = "ARN of KMS key for bucket encryption (if using customer-managed keys instead of AWS-managed)."
# }

# variable "logging_bucket_id" {
#   type        = string
#   default     = null
#   description = "ID of separate S3 bucket for access logging (required for SOC 2, HIPAA, PCI-DSS compliance)."
# }

# variable "enable_cors" {
#   type        = bool
#   default     = false
#   description = "Enable CORS configuration for browser-based access to bucket."
# }
