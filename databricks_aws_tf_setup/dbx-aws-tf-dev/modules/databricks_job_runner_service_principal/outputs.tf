output "service_principal_id" {
  description = "ID of the job runner service principal"
  value       = databricks_service_principal.job_runner.id
}

output "service_principal_application_id" {
  description = "Application ID (UUID) of the job runner service principal"
  value       = databricks_service_principal.job_runner.application_id
}

output "oauth_client_id" {
  description = "OAuth client ID for Asset Bundles authentication"
  value       = databricks_service_principal.job_runner.application_id
}

output "oauth_client_secret" {
  description = "OAuth client secret for Asset Bundles authentication (SENSITIVE)"
  value       = databricks_service_principal_secret.job_runner.secret
  sensitive   = true
}

output "databricks_cli_config" {
  description = "Configuration for Databricks CLI and Asset Bundles"
  value = {
    host          = var.workspace_url
    client_id     = databricks_service_principal.job_runner.application_id
    client_secret = databricks_service_principal_secret.job_runner.secret
    auth_type     = "oauth-m2m"
  }
  sensitive = true
}

output "asset_bundle_env_vars" {
  description = "Environment variables for Databricks Asset Bundles (DABs)"
  value       = <<-EOT
    # Add these to your CI/CD environment or .env file:
    export DATABRICKS_HOST="${var.workspace_url}"
    export DATABRICKS_CLIENT_ID="${databricks_service_principal.job_runner.application_id}"
    export DATABRICKS_CLIENT_SECRET="${databricks_service_principal_secret.job_runner.secret}"

    # Verify authentication:
    databricks current-user me

    # Deploy Asset Bundle:
    databricks bundle deploy
  EOT
  sensitive   = true
}
