variable "project_name" {
  type        = string
  description = "Project name for resource naming"
}

variable "env" {
  type        = string
  description = "Environment (e.g., 'dev', 'staging', 'prod')"
}

variable "databricks_role_arn" {
  type        = string
  description = "ARN of Databricks IAM role that needs to use this KMS key"
}
