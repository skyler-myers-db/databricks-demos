variable "catalog_name" {
  description = "Name of the Unity Catalog catalog"
  type        = string
}

variable "metastore_id" {
  description = "Unity Catalog metastore ID"
  type        = string
}

variable "storage_root_url" {
  description = "S3 URL for catalog's managed storage root (e.g., s3://bucket/catalog_name)"
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

variable "assume_role_name" {
  description = "IAM role name to assume for AWS CLI trust updates"
  type        = string
}
