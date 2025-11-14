variable "role_name" {
  description = "Name for the IAM role and instance profile"
  type        = string
}

variable "project_name" {
  description = "Project identifier for tagging"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "managed_policy_arns" {
  description = "List of managed policy ARNs to attach to the instance profile role"
  type        = list(string)
  default     = []
}

variable "inline_policies" {
  description = "Map of inline policy JSON documents to attach to the role"
  type        = map(string)
  default     = {}
}

variable "enable_serverless" {
  description = "Whether to allow Databricks serverless SQL to assume this role"
  type        = bool
  default     = false
}

variable "serverless_external_ids" {
  description = "List of external IDs that serverless principals must present"
  type        = list(string)
  default     = []
}
