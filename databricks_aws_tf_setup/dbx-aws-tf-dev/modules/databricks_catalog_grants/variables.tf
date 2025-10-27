/**
 * Variables for Databricks Catalog Grants Module
 */

variable "catalog_name" {
  description = "Name of the Unity Catalog catalog to configure grants for"
  type        = string
}

variable "catalog_owner_principal" {
  description = "Principal (user email) who will be the catalog owner with ALL PRIVILEGES"
  type        = string
}

variable "job_runner_sp_application_id" {
  description = "Application ID of the job-runner service principal (format: 12345678-1234-1234-1234-123456789abc)"
  type        = string
}

variable "data_engineers_group_name" {
  description = "Name of the data engineers group (from SCIM sync)"
  type        = string
  default     = "data_engineers"
}
