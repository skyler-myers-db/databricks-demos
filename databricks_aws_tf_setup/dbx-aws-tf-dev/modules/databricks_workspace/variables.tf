# ============================================================================
# Databricks Workspace Module Variables
# ============================================================================
# Purpose: Input variables for creating Databricks E2 workspace on AWS
# Module: databricks_workspace
# Provider: databricks.mws (account-level)
# ============================================================================

# ============================================================================
# Account Configuration
# ============================================================================
variable "dbx_account_id" {
  type        = string
  description = "Databricks account ID (find in account console, format: 12345678-1234-1234-1234-123456789012)"

  validation {
    condition     = can(regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", var.dbx_account_id))
    error_message = "Account ID must be a valid UUID format."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region for workspace deployment (must match network and storage configurations)"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Must be a valid AWS region format (e.g., 'us-east-2', 'eu-west-1')."
  }
}

# ============================================================================
# Workspace Naming
# ============================================================================
variable "workspace_name" {
  type        = string
  description = "User-facing workspace display name (can contain spaces, special characters)"

  validation {
    condition     = length(var.workspace_name) >= 3 && length(var.workspace_name) <= 255
    error_message = "Workspace name must be between 3 and 255 characters."
  }
}

variable "deployment_name" {
  type        = string
  description = "Infrastructure deployment name (globally unique, lowercase, alphanumeric, hyphens only). Format: <project>-<env>-<region>"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.deployment_name)) && length(var.deployment_name) >= 4 && length(var.deployment_name) <= 30
    error_message = "Deployment name must be 4-30 characters, lowercase, alphanumeric with hyphens only."
  }
}

# ============================================================================
# Infrastructure Dependencies
# ============================================================================
# These IDs come from previous module outputs:
# - credentials_id: From databricks_storage_config module (mws_credentials)
# - storage_configuration_id: From databricks_storage_config module (mws_storage_configurations)
# - network_id: From databricks_network_config module (mws_networks)
# ============================================================================
variable "credentials_id" {
  type        = string
  description = "ID of Databricks credentials configuration (from databricks_storage_config module output)"
}

variable "storage_configuration_id" {
  type        = string
  description = "ID of Databricks storage configuration (from databricks_storage_config module output)"
}

variable "network_id" {
  type        = string
  description = "ID of Databricks network configuration (from databricks_network_config module output)"
}

# ============================================================================
# Pricing and Features
# ============================================================================
variable "pricing_tier" {
  type        = string
  default     = "PREMIUM"
  description = "Databricks pricing tier (STANDARD, PREMIUM, or ENTERPRISE). Premium required for Unity Catalog, RBAC, IP Access Lists, Private Link."

  validation {
    condition     = contains(["STANDARD", "PREMIUM", "ENTERPRISE"], var.pricing_tier)
    error_message = "Pricing tier must be STANDARD, PREMIUM, or ENTERPRISE."
  }
}

# ============================================================================
# Unity Catalog Configuration
# ============================================================================
# Metastore ID is required since we always create the metastore before workspace.
# Cannot change metastore after assignment (permanent decision).
# ============================================================================
variable "metastore_id" {
  type        = string
  description = "Unity Catalog metastore ID to assign to workspace (from databricks_metastore module output). Required."
}

variable "default_catalog_name" {
  type        = string
  default     = "main"
  description = "Default catalog name for workspace (usually 'main')."

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]*$", var.default_catalog_name))
    error_message = "Catalog name must start with lowercase letter, contain only lowercase letters, numbers, and underscores."
  }
}

# ============================================================================
# Resource Tagging
# ============================================================================
variable "project_name" {
  type        = string
  description = "Project name for resource naming and tagging"
}

variable "env" {
  type        = string
  description = "Environment (e.g., '-dev', '-staging', '-prod') for resource naming and tagging"
}
