variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for VPC. Use /16-/20 for production, /24 acceptable for dev/demo. Must support minimum /26 subnets for Databricks (64 IPs)."

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "VPC CIDR block must be a valid IPv4 CIDR notation."
  }
}

variable "project_name" {
  type        = string
  description = "Name of the project, used for resource naming and tagging."

  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 32
    error_message = "Project name must be between 1 and 32 characters."
  }
}

variable "env" {
  type        = string
  description = "Environment name (e.g., dev, staging, prod). Used for resource naming and tagging."

  validation {
    condition     = contains(["dev", "staging", "prod", "_dev", "_staging", "_prod"], var.env)
    error_message = "Environment must be one of: dev, staging, prod (with or without underscore prefix)."
  }
}

variable "flow_logs_retention_days" {
  type        = number
  default     = 7
  description = "Number of days to retain VPC Flow Logs in CloudWatch. Recommended: 7 for dev, 30-90 for production."

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_logs_retention_days)
    error_message = "Flow logs retention must be a valid CloudWatch Logs retention period."
  }
}
