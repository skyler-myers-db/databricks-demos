/**
 * Databricks Workspace Cross-Account Role Module
 *
 * Purpose:
 * Creates the IAM role that the Databricks control plane assumes to deploy and
 * operate workspace infrastructure (VPC, subnets, EC2, IAM, etc.) in this AWS account.
 *
 * Trust policy strictly follows Databricks guidance: only the Databricks AWS account
 * (414351767826 for commercial regions) is allowed to assume the role, guarded by the
 * Databricks account-level external ID. EC2 is intentionally NOT included here; any
 * instance-profile usage must be handled by a separate role.
 */

resource "aws_iam_role" "workspace_cross_account" {
  name        = var.role_name
  path        = "/databricks/"
  description = "Databricks cross-account role for workspace provisioning and operations"

  assume_role_policy = data.aws_iam_policy_document.workspace_trust.json

  max_session_duration = 3600

  tags = {
    Name        = var.role_name
    Purpose     = "Databricks workspace cross-account access"
    Environment = var.env
    Project     = var.project_name
  }
}

/**
 * Trust policy: Databricks control plane (account 414351767826) + external ID
 */
data "aws_iam_policy_document" "workspace_trust" {
  statement {
    sid     = "DatabricksControlPlaneTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::414351767826:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.dbx_account_id]
    }
  }
}

output "role_arn" {
  description = "ARN of the Databricks workspace cross-account role"
  value       = aws_iam_role.workspace_cross_account.arn
}

output "role_name" {
  description = "Name of the Databricks workspace cross-account role"
  value       = aws_iam_role.workspace_cross_account.name
}
