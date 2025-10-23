variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where subnets will be created."
}

variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block of the VPC, used for subnet CIDR calculations."

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "VPC CIDR block must be a valid IPv4 CIDR notation."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones to create subnets in. Must have at least 2 zones for Databricks."

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required for Databricks high availability."
  }
}

variable "subnet_count" {
  type        = number
  description = "Number of private and public subnet pairs to create. Minimum 2 for Databricks HA."
  default     = 2

  validation {
    condition     = var.subnet_count >= 2 && var.subnet_count <= 6
    error_message = "Subnet count must be between 2 and 6 for optimal AZ distribution."
  }
}

variable "private_subnet_newbits" {
  type        = number
  description = "Number of bits to add to VPC CIDR for private subnets. Example: 2 creates /26 from /24 VPC (64 IPs, Databricks minimum)."
  default     = 2

  validation {
    condition     = var.private_subnet_newbits >= 2 && var.private_subnet_newbits <= 8
    error_message = "Private subnet newbits must be between 2 and 8 to ensure valid subnet sizes."
  }
}

variable "public_subnet_newbits" {
  type        = number
  description = "Number of bits to add to VPC CIDR for public subnets. Example: 4 creates /28 from /24 VPC (16 IPs, sufficient for NAT GW)."
  default     = 4

  validation {
    condition     = var.public_subnet_newbits >= 3 && var.public_subnet_newbits <= 8
    error_message = "Public subnet newbits must be between 3 and 8 to ensure valid subnet sizes."
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
