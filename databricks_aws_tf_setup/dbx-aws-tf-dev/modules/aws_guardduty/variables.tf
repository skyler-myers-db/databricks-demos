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
  description = "Email address for GuardDuty threat alerts"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Must be a valid email address."
  }
}
