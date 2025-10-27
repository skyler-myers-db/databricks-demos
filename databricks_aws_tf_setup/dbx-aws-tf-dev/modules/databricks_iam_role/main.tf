/**
 * Databricks IAM Cross-Account Role Module
 *
 * Purpose:
 * Creates IAM role for Databricks cross-account access to AWS resources.
 * This role is used for BOTH workspace provisioning AND Unity Catalog storage access.
 *
 * Key Features:
 * - Trust policy for Databricks Unity Catalog role (414351767826)
 * - External ID condition using Databricks account ID (prevents confused deputy)
 * - Ready for S3, KMS, and EC2 policy attachments
 *
 * Security:
 * - Principle of least privilege (no inline policies)
 * - External ID prevents confused deputy problem
 * - Allows Databricks to assume role for EC2 and storage operations
 *
 * Databricks Documentation:
 * https://docs.databricks.com/aws/iam/aws-storage-role.html
 *
 * Cost: $0/month (IAM roles are free)
 */

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# IAM role for Databricks cross-account access
# SECURITY: Uses self-assuming trust policy per official Databricks docs
# Per: https://docs.databricks.com/aws/storage/storage-configuration.html
locals {
  databricks_trust_principal = "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"
  account_root_principal     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  self_role_arn              = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/databricks/${var.role_name}"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "DatabricksAndSelfAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = [
        local.databricks_trust_principal,
        local.account_root_principal
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.dbx_account_id]
    }

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:PrincipalArn"
      values = [
        local.databricks_trust_principal,
        local.self_role_arn
      ]
    }
  }
}

resource "aws_iam_role" "databricks_storage" {
  name        = var.role_name
  description = "Databricks cross-account role for workspace provisioning and Unity Catalog storage access"
  path        = "/databricks/"

  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  # Maximum session duration for assumed role
  max_session_duration = 3600 # 1 hour (default)

  tags = {
    Name                = var.role_name
    Purpose             = "Databricks cross-account storage access"
    DatabricksWorkspace = var.workspace_name
    SecurityScope       = "Databricks Unity Catalog workspace root storage"
    TrustPrincipal      = "unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL + Self-assuming"
  }
}

# Outputs for policy attachment and configuration
output "role_arn" {
  description = "ARN of the Databricks IAM role (use in Databricks storage configuration)"
  value       = aws_iam_role.databricks_storage.arn
}

output "role_name" {
  description = "Name of the Databricks IAM role"
  value       = aws_iam_role.databricks_storage.name
}

output "role_id" {
  description = "Unique ID of the IAM role"
  value       = aws_iam_role.databricks_storage.id
}

output "role_path" {
  description = "Path of the IAM role"
  value       = aws_iam_role.databricks_storage.path
}

output "trust_policy" {
  description = "Trust policy document (for validation)"
  value       = aws_iam_role.databricks_storage.assume_role_policy
}

# Cost analysis
output "cost_estimate" {
  description = "Monthly cost estimate for this IAM role"
  value = {
    role_cost     = "$0.00/month (IAM roles are free)"
    api_calls     = "~$0.00/month (STS AssumeRole calls typically <$0.01)"
    total_monthly = "~$0.00/month"
    notes         = "IAM roles and policies have no direct cost. Only STS API calls incur charges ($0.0004 per 1000 calls)."
  }
}

# Configuration status
output "configuration_status" {
  description = "Module configuration status and next steps"
  value = {
    step_completed = "Step 2: IAM Role Created with Self-Assuming Trust Policy"
    trust_principals = [
      "Databricks Unity Catalog: arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL",
      "Self-assuming: arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/databricks/${var.role_name}"
    ]
    external_id     = "Configured with Databricks account ID: ${var.dbx_account_id}"
    security_model  = "Self-assuming role for Unity Catalog workspace root storage (per official Databricks docs)"
    documentation   = "Per Databricks docs: https://docs.databricks.com/aws/storage/storage-configuration.html"
    next_step       = "Step 3: Attach S3 access policy to this role"
    policy_required = "IAM policy granting s3:GetObject, s3:PutObject, s3:DeleteObject, s3:ListBucket on workspace root bucket"
    note            = "Trust policy uses self-reference pattern as specified in official Databricks documentation"
  }
}
