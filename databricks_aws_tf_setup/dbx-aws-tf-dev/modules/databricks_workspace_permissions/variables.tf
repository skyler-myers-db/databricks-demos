/**
 * Databricks Workspace Permissions Module - Input Variables
 *
 * Required for assigning SCIM-synced users/groups to workspaces
 */

variable "workspace_id" {
  description = "Workspace ID to assign permissions to"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.workspace_id))
    error_message = "Workspace ID must be numeric."
  }
}

variable "admin_user_email" {
  description = "Email of the user to assign as workspace admin (must exist via SCIM sync from Google)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.admin_user_email))
    error_message = "Must be a valid email address format."
  }
}

variable "data_engineers_group_name" {
  description = "Name of the data engineers group (must exist via SCIM sync from Google)"
  type        = string
  default     = "data_engineers"
}

variable "assign_data_engineers_group" {
  description = "Whether to assign the data_engineers group to the workspace"
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Project name for consistent naming"
  type        = string
}

variable "env" {
  description = "Environment (e.g., '-dev', '-staging', '-prod')"
  type        = string
}
