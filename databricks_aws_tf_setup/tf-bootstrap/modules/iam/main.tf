data "aws_iam_policy_document" "assume_databricks" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["*"] # Databricks will create a trust policy during credentials config; narrow later with AWS account IDs if desired.
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = ["databricks"]
    }
  }
}

resource "aws_iam_role" "databricks_cross_account" {
  name               = "${var.project_name}-dbx-cross-account"
  assume_role_policy = data.aws_iam_policy_document.assume_databricks.json
  tags               = var.tags
}

# Permissions for root & log buckets + KMS
data "aws_iam_policy_document" "dbx_access" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [var.s3_root_arn, var.s3_logs_arn]
  }
  statement {
    actions   = ["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:AbortMultipartUpload"]
    resources = ["${var.s3_root_arn}/*","${var.s3_logs_arn}/*"]
  }
  statement {
    actions   = ["kms:Decrypt","kms:Encrypt","kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_policy" "dbx_access" {
  name   = "${var.project_name}-dbx-access"
  policy = data.aws_iam_policy_document.dbx_access.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.databricks_cross_account.name
  policy_arn = aws_iam_policy.dbx_access.arn
}

output "databricks_cross_account_role_arn" { value = aws_iam_role.databricks_cross_account.arn }
