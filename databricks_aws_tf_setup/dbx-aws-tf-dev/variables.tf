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

# variable "dbx_ws_client_id" {
#   type        = string
#   description = "Client ID of the service principal of the workspace"
# }

# variable "dbx_ws_client_secret" {
#   type        = string
#   description = "Client secret of the service principal of the workspace"
# }

# Workspace creation variables
# variable "dbx_ws_name" {
#   type        = string
#   description = "Name of the Databricks workspace"
# }

# variable "dbx_ws_deployment_name" {
#   type        = string
#   description = "Deployment name for the workspace (must be unique, lowercase, alphanumeric)"
# }

# variable "dbx_credentials_id" {
#   type        = string
#   description = "ID of the credentials configuration"
# }

# variable "dbx_storage_config_id" {
#   type        = string
#   description = "ID of the storage configuration"
# }

variable "dbx_network_id" {
  type        = string
  description = "ID of the network configuration"
  default     = null
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
