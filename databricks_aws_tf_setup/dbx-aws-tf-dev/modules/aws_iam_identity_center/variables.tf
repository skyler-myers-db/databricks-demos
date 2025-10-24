# ============================================================================
# AWS IAM Identity Center Module Variables
# ============================================================================

variable "environment" {
  description = "Environment name (dev, prod, staging, etc.)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "databricks"
}

# ============================================================================
# Databricks Service Principal Configuration
# ============================================================================

variable "existing_service_principal_client_id" {
  description = "Client ID of the existing Databricks account admin service principal (from terraform.tfvars)"
  type        = string
  sensitive   = true
}

variable "oauth_token_lifetime_seconds" {
  description = "Lifetime of OAuth token for SCIM authentication (default: 1 year = 31536000 seconds)"
  type        = number
  default     = 31536000

  validation {
    condition     = var.oauth_token_lifetime_seconds >= 86400 && var.oauth_token_lifetime_seconds <= 31536000
    error_message = "OAuth token lifetime must be between 1 day (86400s) and 1 year (31536000s)."
  }
}

# ============================================================================
# Databricks Group Configuration
# ============================================================================

variable "group_data_engineers_name" {
  description = "Name of the data engineers group in Databricks"
  type        = string
  default     = "data_engineers"
}



# ============================================================================
# Unity Catalog Configuration
# ============================================================================

variable "unity_catalog_name" {
  description = "Name of the Unity Catalog to grant permissions on"
  type        = string
  default     = "main"
}

# ============================================================================
# Tags
# ============================================================================

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
