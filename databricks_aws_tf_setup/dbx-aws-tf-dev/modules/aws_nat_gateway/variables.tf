variable "subnet_count" {
  type        = number
  description = "Number of NAT Gateways to create (one per AZ for high availability). Minimum 2 for production."

  validation {
    condition     = var.subnet_count >= 1 && var.subnet_count <= 6
    error_message = "Subnet count must be between 1 and 6. Use 2+ for production HA."
  }
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs where NAT Gateways will be placed (one per AZ)."

  validation {
    condition     = length(var.public_subnet_ids) >= 1
    error_message = "At least one public subnet ID is required for NAT Gateway placement."
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

variable "internet_gateway_id" {
  type        = string
  description = "The ID of the Internet Gateway. NAT Gateway requires IGW to exist first (dependency)."

  validation {
    condition     = can(regex("^igw-", var.internet_gateway_id))
    error_message = "Internet Gateway ID must be a valid IGW identifier starting with 'igw-'."
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
