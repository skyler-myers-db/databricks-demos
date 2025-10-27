variable "catalog_name" {
  description = "Name of the Unity Catalog catalog"
  type        = string
}

variable "metastore_id" {
  description = "Unity Catalog metastore ID"
  type        = string
}

variable "storage_bucket_name" {
  description = "S3 bucket name for catalog storage"
  type        = string
}

variable "storage_bucket_arn" {
  description = "S3 bucket ARN for catalog storage"
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID (E2 format) - used as initial external ID"
  type        = string
}

variable "storage_prefix" {
  description = "Prefix/directory within the bucket for this catalog"
  type        = string
  default     = ""
}

variable "aws_account_id" {
  description = "AWS account ID where the bucket exists"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "assume_role_name" {
  description = "IAM role name to assume when updating trust policies"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of KMS key for S3 bucket encryption"
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
