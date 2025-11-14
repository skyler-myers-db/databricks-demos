variable "role_name" {
  description = "Name of the IAM role that backs the storage credential"
  type        = string
}

variable "storage_credential_name" {
  description = "Name for the Databricks storage credential"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the S3 bucket used for Unity Catalog storage"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID where the bucket lives"
  type        = string
}

variable "aws_region" {
  description = "AWS region for the bucket"
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

variable "initial_external_id" {
  description = "Initial external ID (often Databricks account ID) used before the credential ID is known"
  type        = string
}

variable "assume_role_name" {
  description = "Name of the IAM role to assume when updating the trust policy via AWS CLI"
  type        = string
}

variable "kms_key_arns" {
  description = "List of KMS key ARNs needed for bucket access"
  type        = list(string)
  default     = []
}

variable "enable_file_events" {
  description = "Whether to grant permissions for managed file events"
  type        = bool
  default     = true
}

variable "create_external_location" {
  description = "Create a Databricks external location pointing at the bucket"
  type        = bool
  default     = true
}

variable "external_location_name" {
  description = "Name of the external location (if created)"
  type        = string
  default     = ""
}

variable "external_location_url" {
  description = "S3 URL for the external location"
  type        = string
  default     = ""
}
