/**
 * Databricks Cross-Account Policy Module - Input Variables
 *
 * Required for attaching cross-account compute permissions to Databricks IAM role
 */

variable "policy_name" {
  description = "Name of the IAM policy for cross-account compute access"
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
