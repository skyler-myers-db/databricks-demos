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

# ============================================================================
# User Provisioning Variables
# ============================================================================

variable "workspace_admin_email" {
  type        = string
  default     = "skyler@entrada.ai"
  description = "Email of user to assign as workspace admin (must exist via Google SCIM sync)"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.workspace_admin_email))
    error_message = "Must be a valid email address format."
  }
}

variable "data_engineers_group_name" {
  type        = string
  default     = "data_engineers"
  description = "Name of the data engineers group in Google Workspace (synced via SCIM)"
}

variable "assign_data_engineers_group" {
  type        = bool
  default     = true
  description = "Whether to assign the data_engineers group to the workspace"
}

# ============================================================================
# Unity Catalog and Data Storage Variables
# ============================================================================

variable "catalog_name" {
  type        = string
  default     = "datapact"
  description = "Name of the Unity Catalog catalog to create"

  validation {
    condition     = can(regex("^[a-z0-9_]+$", var.catalog_name))
    error_message = "Catalog name must contain only lowercase letters, numbers, and underscores."
  }
}

variable "job_runner_sp_name" {
  type        = string
  default     = "job-runner"
  description = "Name of the service principal for running jobs via Databricks Asset Bundles"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.job_runner_sp_name))
    error_message = "Service principal name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Allow Terraform to destroy S3 buckets with contents (USE WITH EXTREME CAUTION in production)"
}

# ============================================================================
# Cluster Policies Variables
# ============================================================================

variable "cost_center" {
  type        = string
  default     = "data-platform"
  description = "Cost center for tagging and chargeback"
}

variable "cluster_policy_allowed_instance_types" {
  type = list(string)
  default = [
    "m5.large",
    "m5.xlarge",
    "m5.2xlarge",
    "m5.4xlarge",
    "m5.8xlarge",
    "r5.large",
    "r5.xlarge",
    "r5.2xlarge",
    "r5.4xlarge",
    "c5.xlarge",
    "c5.2xlarge",
    "c5.4xlarge",
    "i3.xlarge",
    "i3.2xlarge",
    "i3.4xlarge"
  ]
  description = "List of allowed EC2 instance types for data engineering clusters"
}

variable "cluster_policy_default_instance_type" {
  type        = string
  default     = "m5.xlarge"
  description = "Default EC2 instance type for data engineering clusters"
}

variable "cluster_policy_analyst_instance_types" {
  type = list(string)
  default = [
    "m5.large",
    "m5.xlarge",
    "m5.2xlarge",
    "r5.large",
    "r5.xlarge",
    "c5.large",
    "c5.xlarge"
  ]
  description = "List of allowed EC2 instance types for analyst clusters"
}

variable "cluster_policy_analyst_default_instance_type" {
  type        = string
  default     = "m5.large"
  description = "Default EC2 instance type for analyst clusters"
}

variable "catalog_owner_email" {
  type        = string
  description = "Email address of the catalog owner (typically the main admin user)"
  sensitive   = true
}
