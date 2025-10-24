variable "aws_tags" {
  type        = map(string)
  default     = {}
  description = "A collection of common tags to place on deployed AWS resources"
}

variable "project_name" {
  type        = string
  default     = "dbx-tf"
  description = "Name of the Terraform project"
}

variable "env" {
  type        = string
  default     = "-dev"
  description = "Environment to deploy the resources to"
}

variable "aws_region" {
  type        = string
  default     = "us-east-2"
  description = "AWS region resources will be deployed to (e.g., 'us-east-1')"
}

variable "dbx_account_id" {
  type        = string
  description = "The account ID of the Databricks instance. It can be found in the Databricks account console."
}

variable "dbx_acc_client_id" {
  type        = string
  description = "Client ID of the service principal with account admin privileges"
}

variable "dbx_acc_client_secret" {
  type        = string
  description = "Client secret of the service principle with account admin privileges"
}

variable "dbx_network_id" {
  type        = string
  description = "ID of the network configuration"
  default     = null
}

# Unity Catalog Variables
variable "dbx_metastore_owner_email" {
  type        = string
  description = "Email address of Unity Catalog metastore owner (must be a Databricks account admin)"
  sensitive   = true

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.dbx_metastore_owner_email))
    error_message = "Must be a valid email address format."
  }
}

# AWS Account Creation Variables
variable "account_email" {
  type        = string
  description = "Email address for the new AWS account (must be unique globally)"
}

variable "parent_ou_id" {
  type        = string
  description = "Parent Organizational Unit ID or root organization ID"
}

variable "aws_acc_switch_role" {
  type        = string
  default     = "OrganizationAccountAccessRole"
  description = "The name of the role to assume in the new AWS account"
}

# ============================================================================
# Networking Module Variables
# ============================================================================

variable "vpc_cidr_block" {
  type        = string
  default     = "10.0.0.0/24"
  description = "CIDR block for VPC. /24 for demo (256 IPs), use /16-/20 for production. Must support minimum /26 subnets for Databricks."
}

variable "subnet_count" {
  type        = number
  default     = 2
  description = "Number of private/public subnet pairs to create (minimum 2 for Databricks HA)."

  validation {
    condition     = var.subnet_count >= 2 && var.subnet_count <= 6
    error_message = "Subnet count must be between 2 and 6 for optimal AZ distribution."
  }
}

variable "private_subnet_newbits" {
  type        = number
  default     = 2
  description = "Bits to add to VPC CIDR for private subnets. 2 = /26 subnets from /24 VPC (64 IPs, Databricks minimum requirement)."

  validation {
    condition     = var.private_subnet_newbits >= 2 && var.private_subnet_newbits <= 8
    error_message = "Private subnet newbits must be between 2 and 8 to ensure valid subnet sizes."
  }
}

variable "public_subnet_newbits" {
  type        = number
  default     = 4
  description = "Bits to add to VPC CIDR for public subnets. 4 = /28 subnets from /24 VPC (16 IPs, sufficient for NAT Gateways only)."

  validation {
    condition     = var.public_subnet_newbits >= 3 && var.public_subnet_newbits <= 8
    error_message = "Public subnet newbits must be between 3 and 8 to ensure valid subnet sizes."
  }
}

# ============================================================================
# AWS Budgets Variables
# ============================================================================
variable "monthly_budget_limit" {
  type        = number
  default     = 1000
  description = "Monthly AWS budget limit in USD for this Databricks project (total AWS costs)"
}

variable "dbu_budget_limit" {
  type        = number
  default     = 500
  description = "Monthly budget for Databricks DBU spending only (subset of monthly_budget_limit)"
}

variable "create_dbu_budget" {
  type        = bool
  default     = false
  description = "Create a separate budget specifically for Databricks DBU tracking"
}

variable "budget_alert_emails" {
  type        = list(string)
  default     = []
  description = "Email addresses to receive AWS budget alerts (use email variable if not specified)"
}

variable "budget_start_date" {
  type        = string
  default     = null
  description = "Budget start date in YYYY-MM-01 format (defaults to current month if null)"
}

variable "admin_email" {
  type        = string
  default     = "skyler@entrada.ai"
  description = "Administrator email address for alerts and notifications"
}
