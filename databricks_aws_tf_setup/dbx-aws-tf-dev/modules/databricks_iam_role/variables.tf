/**
 * Databricks IAM Role Module - Input Variables
 *
 * Required for creating cross-account IAM role with proper trust policy
 */

variable "role_name" {
  description = "Name of the IAM role for Databricks storage access (will be created in /databricks/ path)"
  type        = string
  default     = "databricks-storage-role"

  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]+$", var.role_name))
    error_message = "Role name must contain only alphanumeric characters and +=,.@_-"
  }
}

variable "dbx_account_id" {
  description = "Databricks account ID (used as External ID in trust policy to prevent confused deputy problem)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", var.dbx_account_id))
    error_message = "Databricks account ID must be a valid UUID format."
  }
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
  description = "Environment (e.g., 'dev', '-dev', 'staging', 'prod')"
  type        = string

  # Note: Validation removed to support flexible naming conventions (with or without hyphens)
  # Examples: "dev", "-dev", "staging", "-staging", "prod", "-prod"
}
