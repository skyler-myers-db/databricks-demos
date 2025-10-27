# Cross-Account AWS Deployment Guide

## Overview
This setup creates a new AWS account via AWS Organizations and deploys all resources into that account, not your root account.

## How It Works

### 1. **Two AWS Providers**

```terraform
# providers.tf

# Root account - for Organizations management
provider "aws" {
  alias  = "root"
  region = var.aws_region
  # Uses your CLI credentials
}

# Dev account - assumes role into newly created account
provider "aws" {
  alias  = "dev_account"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${module.aws_account.account_id}:role/OrganizationAccountAccessRole"
  }
}
```

### 2. **Dependency Management**

```terraform
# main.tf

# STEP 1: Create account (uses root provider)
module "aws_account" {
  providers = { aws = aws.root }
  # ...
}

# STEP 2: Create resources in new account (uses dev_account provider)
module "networking" {
  providers = { aws = aws.dev_account }

  depends_on = [module.aws_account]  # Waits for account creation
}
```

## Setup Steps

### 1. **Get Your Organization Root ID**

```bash
aws organizations list-roots --profile root
```

Copy the root ID (format: `r-xxxx`) and update `envs/dev.tfvars`:

```terraform
parent_ou_id = "r-abc123"
```

### 2. **Configure Unique Email**

Each AWS account needs a unique email. Use email aliases:

```terraform
# envs/dev.tfvars
account_email = "skyler+dev@entrada.ai"      # Dev
account_email = "skyler+staging@entrada.ai"  # Staging
account_email = "skyler+prod@entrada.ai"     # Prod
```

### 3. **Ensure CLI Credentials**

Your AWS CLI must be configured with root/management account credentials:

```bash
aws configure --profile root
# Or use your default profile if it has Organizations access
```

### 4. **Apply Terraform**

```bash
terraform init
terraform plan -var-file="envs/common.tfvars" -var-file="envs/dev.tfvars"
terraform apply -var-file="envs/common.tfvars" -var-file="envs/dev.tfvars"
```

## Execution Order

Terraform automatically handles dependencies:

1. ✅ Creates AWS account using `root` provider
2. ✅ Waits for account creation to complete
3. ✅ Assumes `OrganizationAccountAccessRole` into new account
4. ✅ Creates VPC and other resources in the new account using `dev_account` provider

## How Cross-Account Access Works

1. When you create an account via Organizations, AWS automatically creates the `OrganizationAccountAccessRole` role
2. This role trusts your root/management account
3. Your root account can assume this role to deploy resources
4. The `dev_account` provider automatically assumes this role

## Adding More Resources

All modules that should deploy to the dev account must use the `dev_account` provider:

```terraform
module "workspaces" {
  source = "./modules/workspaces"

  providers = {
    aws        = aws.dev_account
    databricks = databricks.ws_dev
  }

  depends_on = [module.aws_account]
}
```

## Important Notes

- ⚠️ Account creation takes 2-5 minutes
- ⚠️ Email addresses must be globally unique across ALL AWS accounts
- ⚠️ `close_on_deletion = true` means the account will be closed on `terraform destroy`
- ⚠️ Account closure is a 90-day process, and you can't reuse the email immediately
- ✅ The `lifecycle { prevent_destroy = true }` prevents accidental account deletion

## Troubleshooting

### "AssumeRole operation: Access Denied"
- Ensure your CLI credentials have Organizations permissions
- Verify the account was created successfully
- Wait a few minutes for role propagation

### "Email already in use"
- Each AWS account needs a unique email
- Use + addressing: `youremail+suffix@domain.com`
- Or use different emails for each environment

### "Cannot find organization root"
```bash
# Get your root ID
aws organizations describe-organization
```
