variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where VPC endpoints will be created."

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must be a valid VPC identifier starting with 'vpc-'."
  }
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs where interface endpoint ENIs will be placed (multi-AZ for HA)."

  validation {
    condition     = length(var.private_subnet_ids) >= 1
    error_message = "At least one private subnet ID is required for interface endpoints."
  }

  validation {
    condition     = alltrue([for id in var.private_subnet_ids : can(regex("^subnet-", id))])
    error_message = "All subnet IDs must be valid subnet identifiers starting with 'subnet-'."
  }
}

variable "private_route_table_ids" {
  type        = list(string)
  description = "List of private route table IDs for S3 gateway endpoint association."

  validation {
    condition     = length(var.private_route_table_ids) >= 1
    error_message = "At least one private route table ID is required for gateway endpoints."
  }

  validation {
    condition     = alltrue([for id in var.private_route_table_ids : can(regex("^rtb-", id))])
    error_message = "All route table IDs must be valid identifiers starting with 'rtb-'."
  }
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security group IDs for interface endpoints (controls HTTPS access from private subnets)."

  validation {
    condition     = length(var.security_group_ids) >= 1
    error_message = "At least one security group ID is required for interface endpoints."
  }

  validation {
    condition     = alltrue([for id in var.security_group_ids : can(regex("^sg-", id))])
    error_message = "All security group IDs must be valid identifiers starting with 'sg-'."
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
