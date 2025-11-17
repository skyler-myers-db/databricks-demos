module "dbx_quickstart" {
  source = "./modules/dbx_quickstart"

  providers = {
    aws            = aws
    databricks.mws = databricks.mws
  }

  project_name = var.project_name
  parent_ou_id = var.parent_ou_id
  tags         = var.aws_tags
  dbx_acc_id   = var.dbx_acc_id
}
