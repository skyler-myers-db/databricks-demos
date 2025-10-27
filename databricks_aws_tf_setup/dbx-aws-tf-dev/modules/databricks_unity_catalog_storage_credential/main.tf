# ============================================================================
# UNITY CATALOG STORAGE CREDENTIAL MODULE
# ============================================================================
# Purpose: Creates a REUSABLE storage credential for Unity Catalog
# Scope: One credential per S3 bucket, can be used by multiple catalogs
# ============================================================================

# ============================================================================
# Local helpers
# ============================================================================
locals {
  uc_trust_principal  = "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"
  uc_account_root_arn = "arn:aws:iam::${var.aws_account_id}:root"
  uc_self_role_arn    = "arn:aws:iam::${var.aws_account_id}:role/${var.project_name}-${var.env}-unity-catalog-storage-role"
  uc_assume_role_arn  = "arn:aws:iam::${var.aws_account_id}:role/${var.assume_role_name}"
}

# ============================================================================
# IAM ROLE FOR STORAGE CREDENTIAL
# ============================================================================
resource "aws_iam_role" "unity_catalog_storage" {
  name               = "${var.project_name}-${var.env}-unity-catalog-storage-role"
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json

  tags = {
    Name    = "${var.project_name}-${var.env}-unity-catalog-storage-role"
    Purpose = "databricks-unity-catalog-storage"
    Project = var.project_name
    Env     = var.env
  }
}

# Trust policy: Databricks Unity Catalog + self-assuming
data "aws_iam_policy_document" "trust_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.uc_trust_principal, local.uc_account_root_arn]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.databricks_account_id]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:PrincipalArn"
      values   = [local.uc_trust_principal, local.uc_self_role_arn]
    }
  }
}

# ============================================================================
# IAM POLICY - S3 ACCESS
# ============================================================================
resource "aws_iam_role_policy" "s3_access" {
  name   = "${var.project_name}-${var.env}-unity-catalog-s3-policy"
  role   = aws_iam_role.unity_catalog_storage.id
  policy = data.aws_iam_policy_document.s3_access.json
}

data "aws_iam_policy_document" "s3_access" {
  # Full S3 bucket access (including multipart uploads)
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload"
    ]
    resources = [
      var.storage_bucket_arn,
      "${var.storage_bucket_arn}/*"
    ]
  }

  # KMS encryption/decryption
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*"
    ]
    resources = [var.kms_key_arn]
  }

  # Self-assume role
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      local.uc_self_role_arn
    ]
  }
}

# ============================================================================
# IAM POLICY - FILE EVENTS (SNS/SQS)
# ============================================================================
resource "aws_iam_role_policy" "file_events" {
  name   = "${var.project_name}-${var.env}-unity-catalog-file-events-policy"
  role   = aws_iam_role.unity_catalog_storage.id
  policy = data.aws_iam_policy_document.file_events.json
}

data "aws_iam_policy_document" "file_events" {
  statement {
    sid    = "ManagedFileEventsSetupStatement"
    effect = "Allow"
    actions = [
      "s3:GetBucketNotification",
      "s3:PutBucketNotification",
      "sns:ListSubscriptionsByTopic",
      "sns:GetTopicAttributes",
      "sns:SetTopicAttributes",
      "sns:CreateTopic",
      "sns:TagResource",
      "sns:Publish",
      "sns:Subscribe",
      "sqs:CreateQueue",
      "sqs:DeleteMessage",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes",
      "sqs:SetQueueAttributes",
      "sqs:TagQueue",
      "sqs:ChangeMessageVisibility",
      "sqs:PurgeQueue"
    ]
    resources = [
      var.storage_bucket_arn,
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:csms-*",
      "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:csms-*"
    ]
  }

  statement {
    sid    = "ManagedFileEventsListStatement"
    effect = "Allow"
    actions = [
      "sqs:ListQueues",
      "sqs:ListQueueTags",
      "sns:ListTopics"
    ]
    resources = [
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:csms-*",
      "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:csms-*"
    ]
  }

  statement {
    sid    = "ManagedFileEventsTeardownStatement"
    effect = "Allow"
    actions = [
      "sns:Unsubscribe",
      "sns:DeleteTopic",
      "sqs:DeleteQueue"
    ]
    resources = [
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:csms-*",
      "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:csms-*"
    ]
  }
}

# Wait for IAM propagation
resource "time_sleep" "iam_propagation" {
  depends_on = [
    aws_iam_role.unity_catalog_storage,
    aws_iam_role_policy.s3_access,
    aws_iam_role_policy.file_events
  ]
  create_duration = "30s"
}

# ============================================================================
# DATABRICKS STORAGE CREDENTIAL
# ============================================================================
resource "databricks_storage_credential" "unity_catalog" {
  provider = databricks.workspace
  name     = var.storage_credential_name
  comment  = "Storage credential for Unity Catalog data bucket (reusable across catalogs)"

  aws_iam_role {
    role_arn = aws_iam_role.unity_catalog_storage.arn
  }

  depends_on = [time_sleep.iam_propagation]
}

resource "time_sleep" "wait_for_trust_update" {
  depends_on      = [databricks_storage_credential.unity_catalog]
  create_duration = "20s"
}

resource "null_resource" "update_trust_policy" {
  triggers = {
    storage_credential_id = databricks_storage_credential.unity_catalog.id
    iam_role_arn          = aws_iam_role.unity_catalog_storage.arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      CREDS=$(aws sts assume-role --role-arn ${local.uc_assume_role_arn} --role-session-name tf-unity-storage-cred --duration-seconds 900 --output text --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]')
      AWS_ACCESS_KEY_ID=$(echo "$CREDS" | awk '{print $1}')
      AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | awk '{print $2}')
      AWS_SESSION_TOKEN=$(echo "$CREDS" | awk '{print $3}')
      export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_DEFAULT_REGION=${var.aws_region}
      aws iam update-assume-role-policy \
        --role-name ${aws_iam_role.unity_catalog_storage.name} \
        --policy-document '{
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": {
                "AWS": [
                  "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL",
                  "${aws_iam_role.unity_catalog_storage.arn}"
                ]
              },
              "Action": "sts:AssumeRole",
              "Condition": {
                "StringEquals": {
                  "sts:ExternalId": "${try(databricks_storage_credential.unity_catalog.aws_iam_role[0].external_id, databricks_storage_credential.unity_catalog.id)}"
                }
              }
            }
          ]
        }'
    EOT
  }

  depends_on = [time_sleep.wait_for_trust_update]
}

resource "time_sleep" "trust_policy_propagation" {
  depends_on      = [null_resource.update_trust_policy]
  create_duration = "10s"
}

# ============================================================================
# EXTERNAL LOCATION (BUCKET ROOT)
# ============================================================================
# Points to the BUCKET ROOT so all catalogs can use it
resource "databricks_external_location" "unity_catalog_root" {
  provider        = databricks.workspace
  name            = "${var.project_name}_${var.env}_unity_catalog_root"
  url             = "s3://${var.storage_bucket_name}"
  credential_name = databricks_storage_credential.unity_catalog.name
  comment         = "Root external location for Unity Catalog storage (shared by all catalogs)"
  skip_validation = false

  depends_on = [
    databricks_storage_credential.unity_catalog,
    time_sleep.trust_policy_propagation
  ]
}
