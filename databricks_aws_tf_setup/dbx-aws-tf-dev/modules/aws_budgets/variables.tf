variable "project_name" {
  type        = string
  description = "Project name for budget naming and filtering"
}

variable "env" {
  type        = string
  description = "Environment (dev, staging, prod) for budget naming and filtering"
}

variable "monthly_budget_limit" {
  type        = number
  description = "Monthly budget limit in USD (total AWS spending for this project)"
  default     = 1000

  validation {
    condition     = var.monthly_budget_limit >= 10
    error_message = "Monthly budget must be at least $10."
  }
}

variable "dbu_budget_limit" {
  type        = number
  description = "Monthly budget limit for Databricks DBU spending only (in USD)"
  default     = 500

  validation {
    condition     = var.dbu_budget_limit >= 10
    error_message = "DBU budget must be at least $10."
  }
}

variable "create_dbu_budget" {
  type        = bool
  description = "Whether to create a separate budget for Databricks DBU tracking"
  default     = false
}

variable "alert_emails" {
  type        = list(string)
  description = "List of email addresses to receive budget alerts"

  validation {
    condition     = length(var.alert_emails) > 0
    error_message = "At least one email address must be provided for budget alerts."
  }

  validation {
    condition     = alltrue([for email in var.alert_emails : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))])
    error_message = "All email addresses must be valid."
  }
}

variable "budget_start_date" {
  type        = string
  description = "Budget start date in YYYY-MM-DD format (defaults to current month)"
  default     = null

  validation {
    condition     = var.budget_start_date == null || can(regex("^\\d{4}-\\d{2}-01$", var.budget_start_date))
    error_message = "Budget start date must be in YYYY-MM-01 format (first day of month)."
  }
}
