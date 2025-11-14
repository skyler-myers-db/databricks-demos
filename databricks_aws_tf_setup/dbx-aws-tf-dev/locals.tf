locals {
  # Environment suffix for machine-readable names; ensures a single leading hyphen.
  workspace_env_suffix = startswith(var.env, "-") ? var.env : "-${var.env}"

  # Core workspace identifiers reused across modules and provider configuration.
  workspace_resource_prefix = "${var.project_name}${local.workspace_env_suffix}"
  workspace_deployment_name = "${local.workspace_resource_prefix}-${var.aws_region}"
  workspace_system_name     = "${local.workspace_resource_prefix}-workspace"
  workspace_url             = "https://${local.workspace_deployment_name}.cloud.databricks.com"
}
