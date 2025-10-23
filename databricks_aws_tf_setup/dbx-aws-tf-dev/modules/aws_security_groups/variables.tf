variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where security groups will be created."

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must be a valid VPC identifier starting with 'vpc-'."
  }
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of private subnet CIDR blocks that need access to VPC endpoints."

  validation {
    condition     = length(var.private_subnet_cidrs) >= 1
    error_message = "At least one private subnet CIDR is required."
  }

  validation {
    condition     = alltrue([for cidr in var.private_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All private subnet CIDRs must be valid IPv4 CIDR notation."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones corresponding to the subnets. Used for tagging security group rules."

  validation {
    condition     = length(var.availability_zones) >= 1
    error_message = "At least one availability zone is required."
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

# Optional: Enable/disable specific security group configurations
variable "enable_privatelink_sg" {
  type        = bool
  default     = false
  description = "Enable security group for Databricks PrivateLink endpoint (Enterprise tier). Set to true when using PrivateLink."
}
