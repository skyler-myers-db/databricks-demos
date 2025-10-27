# ============================================================================
# UNITY CATALOG - STORAGE CREDENTIAL IAM ROLE
# ============================================================================
# Purpose: IAM role that allows Databricks to access S3 bucket for catalog data
# Trust: Databricks Unity Catalog role + SELF-ASSUMING (required by AWS/Databricks)
# ============================================================================

locals {
  catalog_trust_principal         = "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"
  catalog_account_root_arn        = "arn:aws:iam::${var.aws_account_id}:root"
  catalog_self_role_arn           = "arn:aws:iam::${var.aws_account_id}:role/${var.project_name}-${var.env}-${var.catalog_name}-storage-role"
  catalog_storage_credential_name = "${var.project_name}_${var.env}_${var.catalog_name}_storage"
  catalog_assume_role_arn         = "arn:aws:iam::${var.aws_account_id}:role/${var.assume_role_name}"
}

resource "aws_iam_role" "catalog_storage" {
  name               = "${var.project_name}-${var.env}-${var.catalog_name}-storage-role"
  assume_role_policy = data.aws_iam_policy_document.catalog_storage_trust.json

  tags = {
    Name    = "${var.project_name}-${var.env}-${var.catalog_name}-storage-role"
    Purpose = "databricks-unity-catalog-storage"
    Catalog = var.catalog_name
    Project = var.project_name
    Env     = var.env
  }
}

# Note: Trust policy uses Databricks Account ID as initial external ID
# This gets updated automatically to storage credential ID after creation
data "aws_iam_policy_document" "catalog_storage_trust" {
  statement {
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        local.catalog_trust_principal,
        local.catalog_account_root_arn
      ]
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
      values = [
        local.catalog_trust_principal,
        local.catalog_self_role_arn
      ]
    }
  }
}

# ============================================================================
# IAM POLICY - S3 BUCKET ACCESS
# ============================================================================

resource "aws_iam_role_policy" "catalog_storage" {
  name   = "${var.project_name}-${var.env}-${var.catalog_name}-storage-policy"
  role   = aws_iam_role.catalog_storage.id
  policy = data.aws_iam_policy_document.catalog_storage_policy.json
}

data "aws_iam_policy_document" "catalog_storage_policy" {
  # S3 bucket access permissions
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

  # KMS encryption permissions (required if bucket is encrypted)
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*"
    ]
    resources = [var.kms_key_arn]
  }

  # Self-assume role permission (required for self-assuming)
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      local.catalog_self_role_arn
    ]
  }
}

# ============================================================================
# IAM POLICY - FILE EVENTS (OPTIONAL BUT RECOMMENDED)
# ============================================================================
# Allows Databricks to configure S3 event notifications, SNS topics, and SQS queues
# Required for features that use file events (e.g., auto-refresh, incremental data)

resource "aws_iam_role_policy" "catalog_file_events" {
  name   = "${var.project_name}-${var.env}-${var.catalog_name}-file-events-policy"
  role   = aws_iam_role.catalog_storage.id
  policy = data.aws_iam_policy_document.catalog_file_events.json
}

data "aws_iam_policy_document" "catalog_file_events" {
  # Setup permissions for S3 event notifications and SNS/SQS resources
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

  # List permissions for SQS/SNS resources
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

  # Teardown permissions for cleaning up resources
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

# Wait for IAM role to propagate
resource "time_sleep" "catalog_iam_propagation" {
  depends_on = [
    aws_iam_role.catalog_storage,
    aws_iam_role_policy.catalog_storage,
    aws_iam_role_policy.catalog_file_events
  ]
  create_duration = "30s"
}

# ============================================================================
# DATABRICKS STORAGE CREDENTIAL
# ============================================================================
# Registers the IAM role with Unity Catalog as a storage credential
# External ID is automatically retrieved from the created credential

resource "databricks_storage_credential" "catalog" {
  provider = databricks.workspace
  name     = local.catalog_storage_credential_name
  comment  = "Storage credential for ${var.catalog_name} catalog in ${var.env}"

  aws_iam_role {
    role_arn = aws_iam_role.catalog_storage.arn
  }

  depends_on = [time_sleep.catalog_iam_propagation]
}

resource "time_sleep" "catalog_trust_update_wait" {
  depends_on      = [databricks_storage_credential.catalog]
  create_duration = "20s"
}

resource "null_resource" "update_iam_trust_policy" {
  triggers = {
    storage_credential_id = databricks_storage_credential.catalog.id
    iam_role_arn          = aws_iam_role.catalog_storage.arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      CREDS=$(aws sts assume-role --role-arn ${local.catalog_assume_role_arn} --role-session-name tf-${var.catalog_name}-trust-update --duration-seconds 900 --output text --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]')
      AWS_ACCESS_KEY_ID=$(echo "$CREDS" | awk '{print $1}')
      AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | awk '{print $2}')
      AWS_SESSION_TOKEN=$(echo "$CREDS" | awk '{print $3}')
      export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_DEFAULT_REGION=${var.aws_region}
      aws iam update-assume-role-policy \
        --role-name ${aws_iam_role.catalog_storage.name} \
        --policy-document '{
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": {
                "AWS": [
                  "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL",
                  "${aws_iam_role.catalog_storage.arn}"
                ]
              },
              "Action": "sts:AssumeRole",
              "Condition": {
                "StringEquals": {
                  "sts:ExternalId": "${try(databricks_storage_credential.catalog.aws_iam_role[0].external_id, databricks_storage_credential.catalog.id)}"
                }
              }
            }
          ]
        }'
    EOT
  }

  depends_on = [time_sleep.catalog_trust_update_wait]
}

resource "time_sleep" "trust_policy_propagation" {
  depends_on      = [null_resource.update_iam_trust_policy]
  create_duration = "10s"
}

# ============================================================================
# EXTERNAL LOCATION
# ============================================================================
# Defines the S3 location for the catalog's managed storage
# File events enabled for auto-refresh and incremental data processing

resource "databricks_external_location" "catalog" {
  provider        = databricks.workspace
  name            = "${var.project_name}_${var.env}_${var.catalog_name}_location"
  url             = var.storage_prefix != "" ? "s3://${var.storage_bucket_name}/${var.storage_prefix}" : "s3://${var.storage_bucket_name}"
  credential_name = databricks_storage_credential.catalog.name
  comment         = "Managed storage location for ${var.catalog_name} catalog"

  # Enable file events for auto-refresh and change data capture
  # Databricks will configure SNS/SQS automatically with the IAM permissions we granted
  skip_validation = false
  depends_on      = [databricks_storage_credential.catalog, time_sleep.trust_policy_propagation]
}

# ============================================================================
# UNITY CATALOG
# ============================================================================
# Creates the catalog with managed storage location

resource "databricks_catalog" "main" {
  provider     = databricks.workspace
  metastore_id = var.metastore_id
  name         = var.catalog_name
  comment      = "Main catalog for ${var.project_name} ${var.env} environment"

  storage_root = databricks_external_location.catalog.url

  properties = {
    purpose     = "production"
    managed_by  = "terraform"
    environment = var.env
    project     = var.project_name
  }

  depends_on = [databricks_external_location.catalog]
}

# ============================================================================
# DEFAULT SCHEMA
# ============================================================================
# Creates a default schema within the catalog

resource "databricks_schema" "default" {
  provider     = databricks.workspace
  catalog_name = databricks_catalog.main.name
  name         = "default"
  comment      = "Default schema for ${var.catalog_name} catalog"

  properties = {
    created_by = "terraform"
  }
}
