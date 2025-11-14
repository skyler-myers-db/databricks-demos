/**
 * Databricks Unity Catalog Storage Credential Module
 *
 * Creates a self-assuming IAM role and Databricks storage credential for
 * accessing Unity Catalog managed storage. Trust policy follows Databricks
 * guidance: the UC master role and the role itself may assume it, gated by the
 * storage credential external ID. After the credential is created, the trust
 * policy is updated to use the real external ID supplied by Databricks.
 *
 * Optionally creates an external location pointing to the bucket root.
 */

locals {
  uc_master_role_arn        = "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"
  self_role_arn             = "arn:aws:iam::${var.aws_account_id}:role/${var.role_name}"
  assume_role_arn           = "arn:aws:iam::${var.aws_account_id}:role/${var.assume_role_name}"
  inferred_external_name    = "${var.project_name}_${var.env}_root"
  inferred_external_url     = replace(var.bucket_arn, "arn:aws:s3:::", "s3://")
  external_location_name    = length(trimspace(var.external_location_name)) > 0 ? var.external_location_name : local.inferred_external_name
  external_location_url_raw = length(trimspace(var.external_location_url)) > 0 ? var.external_location_url : local.inferred_external_url
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.uc_master_role_arn, local.self_role_arn]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.initial_external_id]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = "/databricks/"
  assume_role_policy = data.aws_iam_policy_document.trust.json

  lifecycle {
    # Trust policy is updated post-creation with the storage credential External ID.
    ignore_changes = [assume_role_policy]
  }

  tags = {
    Name        = var.role_name
    Purpose     = "Databricks UC storage credential"
    Environment = var.env
    Project     = var.project_name
  }
}

data "aws_iam_policy_document" "s3_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:DeleteObjectVersion",
      "s3:DeleteObjectVersionTagging",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload"
    ]
    resources = [var.bucket_arn, "${var.bucket_arn}/*"]
  }

  dynamic "statement" {
    for_each = length(var.kms_key_arns) > 0 ? [1] : []
    content {
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey*", "kms:DescribeKey"]
      resources = var.kms_key_arns
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["s3.${var.aws_region}.amazonaws.com"]
      }
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [local.self_role_arn]
  }
}

resource "aws_iam_role_policy" "s3_access" {
  name   = "${var.role_name}-s3-access"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.s3_access.json
}

resource "aws_iam_role_policy" "file_events" {
  count  = var.enable_file_events ? 1 : 0
  name   = "${var.role_name}-file-events"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.file_events[0].json
}

data "aws_iam_policy_document" "file_events" {
  count = var.enable_file_events ? 1 : 0

  # Bucket notification permissions
  statement {
    sid    = "ManagedFileEventsBucketNotifications"
    effect = "Allow"
    actions = [
      "s3:GetBucketNotification",
      "s3:PutBucketNotification"
    ]
    resources = [var.bucket_arn]
  }

  # Create operations must use resource "*"; restrict by name
  statement {
    sid    = "ManagedFileEventsCreate"
    effect = "Allow"
    actions = [
      "sns:CreateTopic",
      "sqs:CreateQueue",
      "sqs:GetQueueUrl"
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "sns:TopicName"
      values   = ["csms-*"]
    }
    condition {
      test     = "StringLike"
      variable = "sqs:QueueName"
      values   = ["csms-*"]
    }
  }

  # Operate on created SNS topics and SQS queues
  statement {
    sid    = "ManagedFileEventsOperate"
    effect = "Allow"
    actions = [
      "sns:TagResource",
      "sns:Publish",
      "sns:Subscribe",
      "sns:SetTopicAttributes",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic",
      "sqs:TagQueue",
      "sqs:SetQueueAttributes",
      "sqs:GetQueueAttributes",
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:PurgeQueue",
      "sqs:ChangeMessageVisibility",
      "sqs:ListQueueTags"
    ]
    resources = [
      "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:csms-*",
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:csms-*"
    ]
  }

  # Discovery helpers
  statement {
    sid       = "ManagedFileEventsList"
    effect    = "Allow"
    actions   = ["sns:ListTopics", "sqs:ListQueues"]
    resources = ["*"]
  }

  # Teardown operations
  statement {
    sid     = "ManagedFileEventsTeardown"
    effect  = "Allow"
    actions = ["sns:Unsubscribe", "sns:DeleteTopic", "sqs:DeleteQueue"]
    resources = [
      "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:csms-*",
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:csms-*"
    ]
  }
}

resource "databricks_storage_credential" "this" {
  provider = databricks
  name     = var.storage_credential_name
  comment  = "Storage credential for ${var.project_name}-${var.env}"

  aws_iam_role {
    role_arn = aws_iam_role.this.arn
  }
}

resource "time_sleep" "wait_for_credential" {
  depends_on      = [databricks_storage_credential.this]
  create_duration = "20s"
}

resource "null_resource" "update_trust" {
  triggers = {
    credential_id = databricks_storage_credential.this.id
    role_name     = aws_iam_role.this.name
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      CREDS=$(aws sts assume-role --role-arn ${local.assume_role_arn} --role-session-name tf-uc-credential-${var.env} --duration-seconds 900 --output text --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]')
      export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | awk '{print $1}')
      export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | awk '{print $2}')
      export AWS_SESSION_TOKEN=$(echo "$CREDS" | awk '{print $3}')
      export AWS_DEFAULT_REGION=${var.aws_region}
      aws iam update-assume-role-policy \
        --role-name ${aws_iam_role.this.name} \
        --policy-document '{
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": {
                "AWS": [
                  "${local.uc_master_role_arn}",
                  "${local.self_role_arn}"
                ]
              },
              "Action": "sts:AssumeRole",
              "Condition": {
                "StringEquals": {
                  "sts:ExternalId": "${databricks_storage_credential.this.id}"
                }
              }
            }
          ]
        }'
    EOT
  }

  depends_on = [time_sleep.wait_for_credential]
}

resource "databricks_external_location" "this" {
  count           = var.create_external_location ? 1 : 0
  provider        = databricks
  name            = local.external_location_name
  url             = trimsuffix(local.external_location_url_raw, "/")
  credential_name = databricks_storage_credential.this.name
  skip_validation = false

  depends_on = [null_resource.update_trust]
}

output "storage_credential_name" {
  description = "Name of the Databricks storage credential"
  value       = databricks_storage_credential.this.name
}

output "storage_credential_id" {
  description = "ID of the Databricks storage credential"
  value       = databricks_storage_credential.this.id
}

output "iam_role_arn" {
  description = "IAM role ARN backing the storage credential"
  value       = aws_iam_role.this.arn
}

output "external_location_name" {
  description = "Name of the external location (if created)"
  value       = var.create_external_location && length(databricks_external_location.this) > 0 ? databricks_external_location.this[0].name : null
}

output "external_location_url" {
  description = "URL of the external location (if created)"
  value       = var.create_external_location && length(databricks_external_location.this) > 0 ? trimsuffix(databricks_external_location.this[0].url, "/") : null
}
