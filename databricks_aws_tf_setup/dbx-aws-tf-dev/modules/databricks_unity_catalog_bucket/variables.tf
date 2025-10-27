variable "bucket_name" {
  description = "Name of the S3 bucket for Unity Catalog managed storage"
  type        = string
}

variable "force_destroy" {
  description = "Allow Terraform to destroy bucket with contents (use with caution)"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of KMS key for bucket encryption"
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID (E2 account ID format)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID where the bucket resides"
  type        = string
}

variable "aws_tags" {
  description = "AWS resource tags"
  type        = map(string)
  default     = {}
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}
