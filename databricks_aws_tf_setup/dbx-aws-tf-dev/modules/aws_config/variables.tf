variable "project_name" {
  type        = string
  description = "Project name for resource naming"
}

variable "env" {
  type        = string
  description = "Environment (dev, staging, prod)"
}

variable "notification_email" {
  type        = string
  description = "Email address for AWS Config compliance notifications"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Must be a valid email address."
  }
}

variable "config_retention_days" {
  type        = number
  default     = 365
  description = "Number of days to retain AWS Config snapshots"

  validation {
    condition     = var.config_retention_days >= 90 && var.config_retention_days <= 2555
    error_message = "Retention must be between 90 and 2555 days (7 years max)."
  }
}
