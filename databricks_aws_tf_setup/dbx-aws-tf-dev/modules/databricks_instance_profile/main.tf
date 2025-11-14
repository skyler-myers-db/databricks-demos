/**
 * Databricks Instance Profile Module
 *
 * Purpose: Creates the IAM role + instance profile used by Databricks clusters (classic compute).
 * Trust policy allows EC2 (and optionally Databricks serverless role) to assume the role.
 *
 * Optional serverless integration: set `enable_serverless = true` and provide
 * the list of serverless external IDs (typically `databricks-serverless-<workspace-id>`) via
 * `serverless_external_ids` so Databricks serverless SQL can assume the role.
 */

locals {
  serverless_role_arn = "arn:aws:iam::790110701330:role/serverless-customer-resource-role"
  serverless_ext_ids  = var.enable_serverless ? (length(var.serverless_external_ids) > 0 ? var.serverless_external_ids : ["databricks-serverless-*"]) : []
}

data "aws_iam_policy_document" "instance_profile_trust" {
  statement {
    sid     = "AllowEC2ToAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }

  dynamic "statement" {
    for_each = var.enable_serverless ? [1] : []
    content {
      sid     = "AllowServerlessToAssume"
      effect  = "Allow"
      actions = ["sts:AssumeRole"]
      principals {
        type        = "AWS"
        identifiers = [local.serverless_role_arn]
      }
      condition {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = local.serverless_ext_ids
      }
    }
  }
}

resource "aws_iam_role" "instance_profile" {
  name               = var.role_name
  path               = "/databricks/"
  assume_role_policy = data.aws_iam_policy_document.instance_profile_trust.json

  tags = {
    Name        = var.role_name
    Purpose     = "Databricks EC2 instance profile"
    Environment = var.env
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.instance_profile.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies
  name     = each.key
  role     = aws_iam_role.instance_profile.id
  policy   = each.value
}

resource "aws_iam_instance_profile" "this" {
  name = var.role_name
  path = "/databricks/"
  role = aws_iam_role.instance_profile.name
}

output "role_arn" {
  description = "ARN of the IAM role used as the Databricks instance profile"
  value       = aws_iam_role.instance_profile.arn
}

output "instance_profile_arn" {
  description = "Instance profile ARN to register in Databricks workspace"
  value       = aws_iam_instance_profile.this.arn
}

output "role_name" {
  description = "Name of the IAM role used as the Databricks instance profile"
  value       = aws_iam_role.instance_profile.name
}
