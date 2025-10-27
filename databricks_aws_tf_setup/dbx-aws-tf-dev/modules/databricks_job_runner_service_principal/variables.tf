variable "service_principal_name" {
  description = "Display name for the job runner service principal"
  type        = string
  default     = "job-runner"
}

variable "workspace_id" {
  description = "Databricks workspace ID"
  type        = string
}

variable "workspace_url" {
  description = "Databricks workspace URL"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}
