/**
 * Databricks Metastore Module - Input Variables
 *
 * Required for creating Unity Catalog metastore
 */

variable "metastore_name" {
  description = "Name of the Unity Catalog metastore (should include region for clarity, e.g., 'prod-us-west-2-metastore')"
  type        = string

  validation {
    condition     = length(var.metastore_name) >= 3 && length(var.metastore_name) <= 255
    error_message = "Metastore name must be between 3 and 255 characters."
  }
}

variable "aws_region" {
  description = "AWS region where the metastore operates (must match workspace region)"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be valid format (e.g., us-west-2, eu-west-1)."
  }
}

variable "metastore_owner" {
  description = "Email address of the metastore owner (must be Databricks account admin)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.metastore_owner))
    error_message = "Metastore owner must be a valid email address."
  }
}

variable "data_access_config_name" {
  description = "Name of the data access configuration (links IAM role to metastore)"
  type        = string

  validation {
    condition     = length(var.data_access_config_name) >= 3
    error_message = "Data access configuration name must be at least 3 characters."
  }
}

variable "iam_role_arn" {
  description = "ARN of the IAM role for data access (from databricks_iam_role module)"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/", var.iam_role_arn))
    error_message = "IAM role ARN must be valid format."
  }
}

variable "project_name" {
  description = "Project name (for consistent naming)"
  type        = string
}

variable "env" {
  description = "Environment (e.g., 'dev', '-dev', 'staging', 'prod')"
  type        = string

  # Note: Validation removed to support flexible naming conventions (with or without hyphens)
  # Examples: "dev", "-dev", "staging", "-staging", "prod", "-prod"
}
