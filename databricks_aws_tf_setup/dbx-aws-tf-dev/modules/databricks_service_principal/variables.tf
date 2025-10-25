/**
 * Databricks Service Principal Module - Input Variables
 *
 * Required for creating and configuring service principals
 */

variable "service_principal_name" {
  description = "Display name for the service principal (e.g., 'workspace-terraform-dev')"
  type        = string

  validation {
    condition     = length(var.service_principal_name) >= 3 && length(var.service_principal_name) <= 255
    error_message = "Service principal name must be between 3 and 255 characters."
  }
}

variable "workspace_id" {
  description = "Workspace ID to assign the service principal as admin"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.workspace_id))
    error_message = "Workspace ID must be numeric."
  }
}

variable "workspace_url" {
  description = "Workspace URL for provider configuration (e.g., 'https://dbx-tf-dev-us-east-2.cloud.databricks.com')"
  type        = string

  validation {
    condition     = can(regex("^https://.*\\.cloud\\.databricks\\.com$", var.workspace_url))
    error_message = "Workspace URL must be a valid Databricks URL format."
  }
}

variable "project_name" {
  description = "Project name for consistent naming"
  type        = string
}

variable "env" {
  description = "Environment (e.g., '-dev', '-staging', '-prod')"
  type        = string
}
