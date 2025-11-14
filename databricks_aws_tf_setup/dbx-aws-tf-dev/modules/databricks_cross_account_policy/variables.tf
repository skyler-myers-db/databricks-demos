variable "policy_name" {
  description = "Name of the IAM policy"
  type        = string
}

variable "role_name" {
  description = "Name of the IAM role to attach the policy to"
  type        = string
}

variable "workspace_name" {
  description = "Databricks workspace name (for tagging)"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "pass_role_arns" {
  description = "List of IAM role ARNs that Databricks must be able to pass"
  type        = list(string)
  default     = []
}
