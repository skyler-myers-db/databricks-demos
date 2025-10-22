output "workspace_id" { value = module.databricks_account.workspace_id }
output "workspace_url" { value = module.databricks_account.workspace_url }
output "metastore_id" { value = try(module.uc[0].metastore_id, null) }
output "root_bucket" { value = module.storage.root_bucket }
output "log_bucket" { value = module.storage.log_bucket }
