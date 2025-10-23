variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where route tables will be created."

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must be a valid VPC identifier starting with 'vpc-'."
  }
}

variable "subnet_count" {
  type        = number
  description = "Number of subnet pairs (private/public) and corresponding route tables. Minimum 2 for HA."

  validation {
    condition     = var.subnet_count >= 1 && var.subnet_count <= 6
    error_message = "Subnet count must be between 1 and 6."
  }
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs to associate with private route tables."

  validation {
    condition     = length(var.private_subnet_ids) >= 1
    error_message = "At least one private subnet ID is required."
  }
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs to associate with public route table."

  validation {
    condition     = length(var.public_subnet_ids) >= 1
    error_message = "At least one public subnet ID is required."
  }
}

variable "internet_gateway_id" {
  type        = string
  description = "The ID of the Internet Gateway for public subnet routing."

  validation {
    condition     = can(regex("^igw-", var.internet_gateway_id))
    error_message = "Internet Gateway ID must be a valid IGW identifier starting with 'igw-'."
  }
}

variable "nat_gateway_ids" {
  type        = list(string)
  description = "List of NAT Gateway IDs for private subnet routing (one per AZ)."

  validation {
    condition     = length(var.nat_gateway_ids) >= 1
    error_message = "At least one NAT Gateway ID is required."
  }

  validation {
    condition     = alltrue([for id in var.nat_gateway_ids : can(regex("^nat-", id))])
    error_message = "All NAT Gateway IDs must be valid NAT identifiers starting with 'nat-'."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones corresponding to the subnets. Used for naming and tagging."

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
