variable "aws_tags" {
  type = map(string)
  default = {
    Environment  = "dev"
    Project      = "dbx-tf"
    ManagedBy    = "terraform"
    Owner        = "skyler@entrada.ai"
    CostCenter   = "data_engineering"
    BillingGroup = "data_platform"
    Application  = "databricks"
    Team         = "data_platform"
  }
  description = "A collection of common tags to place on deployed AWS resources"
}

variable "project_name" {
  type        = string
  default     = "dbx-tf"
  description = "Name of the Terraform project"
}

variable "aws_region" {
  type        = string
  default     = "us-west-1"
  description = "AWS region resources will be deployed to (e.g., 'us-east-1')"
}

variable "dbx_acc_id" {
  type        = string
  description = "The account ID of the Databricks instance. It can be found in the Databricks account console."
}

variable "dbx_acc_client_id" {
  type        = string
  description = "Client ID of the service principal with account admin privileges."
}

variable "dbx_acc_client_secret" {
  type        = string
  description = "Client secret of the service principle with account admin privileges"
}

variable "parent_ou_id" {
  type        = string
  description = "Parent Organizational Unit ID or root ID"
}
