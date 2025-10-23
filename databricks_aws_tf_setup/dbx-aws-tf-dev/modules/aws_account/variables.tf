variable "project_name" {
  type        = string
  description = "Name of the Terraform project"
}

variable "env" {
  type        = string
  description = "Environment name"
}

variable "account_email" {
  type        = string
  description = "Email address for the AWS account (must be unique across all AWS accounts)"
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
