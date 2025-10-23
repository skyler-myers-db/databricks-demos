# Step 1: Create the AWS account in your organization
# Uses root account provider
module "aws_account" {
  source = "./modules/aws_account"

  providers = {
    aws = aws.root
  }

  project_name  = var.project_name
  env           = var.env
  account_email = var.account_email
  parent_ou_id  = var.parent_ou_id
  tags          = var.aws_tags
}

# Step 2: Create networking resources in the new account
# Uses dev_account provider which assumes role into the new account
# IMPORTANT: Uncomment this after creating the account and setting dev_account_id in terraform.tfvars
module "networking" {
  source = "./modules/networking"

  providers = {
    aws = aws.dev
  }

  env          = var.env
  project_name = var.project_name

  # Explicit dependency - wait for account to be created
  depends_on = [module.aws_account]
}
