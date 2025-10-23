variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where Network ACLs will be created."

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must be a valid VPC identifier starting with 'vpc-'."
  }
}

variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block of the VPC (used for internal traffic rules)."

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "VPC CIDR block must be a valid IPv4 CIDR notation."
  }
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs where Databricks workloads run (NACL will be applied here)."

  validation {
    condition     = length(var.private_subnet_ids) >= 1
    error_message = "At least one private subnet ID is required."
  }

  validation {
    condition     = alltrue([for id in var.private_subnet_ids : can(regex("^subnet-", id))])
    error_message = "All subnet IDs must be valid subnet identifiers starting with 'subnet-'."
  }
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs where NAT Gateways reside (NACL will be applied here)."

  validation {
    condition     = length(var.public_subnet_ids) >= 1
    error_message = "At least one public subnet ID is required."
  }

  validation {
    condition     = alltrue([for id in var.public_subnet_ids : can(regex("^subnet-", id))])
    error_message = "All subnet IDs must be valid subnet identifiers starting with 'subnet-'."
  }
}

variable "project_name" {
  type        = string
  description = "Name of the project, used for resource naming and tagging."
}

variable "env" {
  type        = string
  description = "Environment name (e.g., dev, staging, prod). Used for resource naming and tagging."
}
