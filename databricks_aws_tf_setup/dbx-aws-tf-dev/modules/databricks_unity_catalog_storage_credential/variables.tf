variable "storage_credential_name" {
  description = "Name for the Unity Catalog storage credential"
  type        = string
}

variable "storage_bucket_name" {
  description = "S3 bucket name for Unity Catalog storage"
  type        = string
}

variable "storage_bucket_arn" {
  description = "S3 bucket ARN for Unity Catalog storage"
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID (E2 format) - used as initial external ID"
  type        = string
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
  description = "Name of the IAM role to assume when running AWS CLI updates"
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
