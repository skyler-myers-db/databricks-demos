variable "project_name" {
  type        = string
  description = "Name of the Terraform project"
}

variable "aws_acc_email" {
  type        = string
  description = "Email address for the AWS account (must be unqiue across all AWS accounts)"
  default     = "skyler-tf@entrada.ai"
}

variable "parent_ou_id" {
  type        = string
  description = "Parent Organizational Unit ID or root ID"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the account"
  default     = {}
}

variable "aws_acc_switch_role" {
  type        = string
  default     = "OrganizationAccountAccessRole"
  description = "The name of the role to assume in the new account"
}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for VPC. Use /17-/20 for production, /24 acceptable for dev/demo. Must support minimum /26 subnets for Databricks (64 IPs)."
  default     = "10.0.0.0/17"

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "VPC CIDR block must be a valid IPv4 CIDR notation."
  }
}

variable "dbx_acc_id" {
  type        = string
  description = "The account ID of the Databricks instance. It can be found in the Databricks account console."
}
