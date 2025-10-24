/**
 * Databricks Network Configuration Module - Input Variables
 *
 * Required for creating Databricks account-level network configuration
 */

variable "databricks_account_id" {
  description = "Databricks account ID (UUID format)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", var.databricks_account_id))
    error_message = "Databricks account ID must be a valid UUID format."
  }
}

variable "network_configuration_name" {
  description = "Human-readable name for the network configuration (visible in Databricks UI)"
  type        = string

  validation {
    condition     = length(var.network_configuration_name) >= 3 && length(var.network_configuration_name) <= 255
    error_message = "Network configuration name must be between 3 and 255 characters."
  }
}

variable "vpc_id" {
  description = "ID of the VPC for Databricks workspace (from aws_vpc module)"
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]+$", var.vpc_id))
    error_message = "VPC ID must be valid AWS VPC ID format (vpc-*)."
  }
}

variable "subnet_ids" {
  description = "List of private subnet IDs for Databricks clusters (from aws_subnets module, minimum 2 required in different AZs)"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnets required for high availability (must be in different AZs)."
  }

  validation {
    condition     = alltrue([for id in var.subnet_ids : can(regex("^subnet-[a-z0-9]+$", id))])
    error_message = "All subnet IDs must be valid AWS subnet ID format (subnet-*)."
  }
}

variable "security_group_ids" {
  description = "List of security group IDs for Databricks workspace (from aws_security_groups module, minimum 1 required)"
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) >= 1
    error_message = "At least 1 security group required."
  }

  validation {
    condition     = alltrue([for id in var.security_group_ids : can(regex("^sg-[a-z0-9]+$", id))])
    error_message = "All security group IDs must be valid AWS security group ID format (sg-*)."
  }
}

variable "project_name" {
  description = "Project name (for consistent naming)"
  type        = string
}

variable "env" {
  description = "Environment (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}
