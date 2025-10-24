# ============================================================================
# AWS Budgets Module - Cost Management & Alerts
# ============================================================================
# Purpose: Create AWS Budgets for cost monitoring and alerting
# Cost: FREE (AWS Budgets is free for first 2 budgets, then $0.02/day per budget)
#
# WHAT IT DOES:
# - Monitors actual and forecasted AWS spending
# - Sends email alerts at defined thresholds
# - Prevents bill shock from unexpected costs
# - Required for production cost governance
#
# ALERT TYPES:
# - ACTUAL: Alert when actual spending exceeds threshold
# - FORECASTED: Alert when forecasted spending exceeds threshold (predictive)
#
# BEST PRACTICES:
# - Set multiple thresholds (50%, 80%, 100%, 120%)
# - Use FORECASTED alerts for early warning
# - Filter by tags to track specific projects
# - Review alerts monthly and adjust as needed
# ============================================================================

# ============================================================================
# MONTHLY BUDGET FOR DATABRICKS PROJECT
# ============================================================================
resource "aws_budgets_budget" "databricks_monthly" {
  name              = "${var.project_name}-${var.env}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = var.budget_start_date

  # Filter by project and environment tags
  cost_filter {
    name = "TagKeyValue"
    values = [
      "Project$${var.project_name}",
      "Environment$${var.env}"
    ]
  }

  # Alert 1: 50% threshold (early warning)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
  }

  # Alert 2: 80% threshold (warning)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  # Alert 3: 100% threshold (budget exceeded)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  # Alert 4: 120% threshold (critical overspend)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 120
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }
}

# ============================================================================
# DATABRICKS DBU BUDGET (if tracking separately)
# ============================================================================
# This budget tracks only Databricks compute costs (DBUs)
# Useful for chargeback to specific teams or departments
resource "aws_budgets_budget" "databricks_dbu" {
  count = var.create_dbu_budget ? 1 : 0

  name              = "${var.project_name}-${var.env}-dbu-budget"
  budget_type       = "COST"
  limit_amount      = var.dbu_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = var.budget_start_date

  # Filter by Databricks application tag and usage type
  cost_filter {
    name = "TagKeyValue"
    values = [
      "Application$databricks",
      "Project$${var.project_name}"
    ]
  }

  cost_filter {
    name = "Service"
    values = [
      "AWS Marketplace" # Databricks charges appear here
    ]
  }

  # Alert at 80% threshold
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
  }

  # Alert at 100% threshold
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================
output "monthly_budget_id" {
  description = "ID of the monthly cost budget"
  value       = aws_budgets_budget.databricks_monthly.id
}

output "monthly_budget_name" {
  description = "Name of the monthly cost budget"
  value       = aws_budgets_budget.databricks_monthly.name
}

output "dbu_budget_id" {
  description = "ID of the DBU-specific budget (null if not created)"
  value       = var.create_dbu_budget ? aws_budgets_budget.databricks_dbu[0].id : null
}

output "alert_configuration" {
  description = "Budget alert configuration summary"
  value = {
    monthly_budget = {
      limit        = "$${var.monthly_budget_limit}/month"
      thresholds   = "50% (forecast), 80%, 100%, 120% (actual)"
      alert_emails = var.alert_emails
      filtered_by  = "Project=${var.project_name}, Environment=${var.env}"
    }
    dbu_budget = var.create_dbu_budget ? {
      limit        = "$${var.dbu_budget_limit}/month"
      thresholds   = "80% (forecast), 100% (actual)"
      alert_emails = var.alert_emails
      filtered_by  = "Application=databricks, Project=${var.project_name}"
    } : null
  }
}

# ============================================================================
# USAGE NOTES
# ============================================================================
# Email Confirmation:
# - AWS will send confirmation emails to all addresses
# - Recipients must click "Confirm subscription" link
# - Alerts only sent after confirmation
#
# Cost:
# - First 2 budgets: FREE
# - Additional budgets: $0.02/day (~$0.60/month each)
# - Total cost for this setup: $0.00/month (2 budgets)
#
# Budget Updates:
# - Changes take effect immediately
# - Historical data not affected
# - Can pause/delete budgets at any time
#
# Alert Frequency:
# - Maximum once per day per threshold
# - Forecasted alerts: Daily if forecast exceeds threshold
# - Actual alerts: When actual spending crosses threshold
#
# Monitoring:
# - View budget details: AWS Console → Billing → Budgets
# - Download spending reports: Cost Explorer
# - API access: AWS Budgets API for programmatic checks
# ============================================================================
