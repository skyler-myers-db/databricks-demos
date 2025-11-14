module "dbx_quickstart" {
  source = "./modules/dbx_quickstart"

  providers = {
    aws = aws
  }

  project_name = var.project_name
  parent_ou_id = var.parent_ou_id
  tags         = var.aws_tags
}
