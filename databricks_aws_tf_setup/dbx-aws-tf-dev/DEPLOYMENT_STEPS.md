# Deployment Steps

This Terraform configuration creates AWS resources across multiple accounts, which requires a two-step deployment process.

## Problem

The `aws.dev` provider needs to assume a role in the new AWS account, but that account doesn't exist yet. The provider references `module.aws_account.account_id`, which causes a warning when Terraform tries to validate the provider configuration before the account is created.

## Solution: Two-Step Deployment

### Step 1: Create the AWS Account

1. Ensure the `networking` module is commented out in `main.tf` (it should be by default)
2. Run Terraform to create just the account:
   ```bash
   terraform plan
   terraform apply
   ```
3. Note the account ID from the output (or find it in the AWS Organizations console)

### Step 2: Deploy Networking Resources

1. Uncomment the `networking` module in `main.tf`:
   ```hcl
   module "networking" {
     source = "./modules/networking"

     providers = {
       aws = aws.dev
     }

     env          = var.env
     project_name = var.project_name

     depends_on = [module.aws_account]
   }
   ```

2. Run Terraform again:
   ```bash
   terraform plan
   terraform apply
   ```

## Why This Approach Works

When the networking module is commented out:
- The `aws.dev` provider is defined but not used
- Terraform doesn't validate unused providers
- No warnings appear
- The account is created successfully

After uncommenting the networking module:
- `module.aws_account.account_id` now exists in the state
- The `aws.dev` provider can properly construct the role ARN
- Resources can be created in the new account

This is the cleanest approach and works with the latest versions of all providers.
