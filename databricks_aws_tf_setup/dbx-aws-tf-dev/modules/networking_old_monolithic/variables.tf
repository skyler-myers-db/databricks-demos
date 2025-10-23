variable "tags" {
  type        = map(string)
  default     = {}
  description = "A collection of tags to place on deployed resources"
}

variable "env" {
  type        = string
  default     = "_dev"
  description = "Environment name (e.g., dev, staging, prod)"
}

variable "project_name" {
  type        = string
  default     = "dbx-tf"
  description = "Name of the Terraform project"
}

variable "subnet_count" {
  type        = number
  default     = 2
  description = "Number of private subnets to create (minimum 2 for Databricks)"
}

variable "vpc_cidr_block" {
  type        = string
  default     = "10.0.0.0/24"
  description = "CIDR block for VPC. /24 for demo (256 IPs), use /16-/20 for production. Must support minimum /26 subnets for Databricks."
}

variable "private_subnet_newbits" {
  type        = number
  default     = 2
  description = "Bits to add to VPC CIDR for private subnets. 2 = /26 subnets from /24 VPC (64 IPs, Databricks minimum requirement)."
}

variable "public_subnet_newbits" {
  type        = number
  default     = 4
  description = "Bits to add to VPC CIDR for public subnets. 4 = /28 subnets from /24 VPC (16 IPs, sufficient for NAT Gateways only)."
}
