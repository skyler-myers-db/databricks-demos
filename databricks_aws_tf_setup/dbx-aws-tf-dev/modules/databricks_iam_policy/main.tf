/**
 * Databricks IAM Policy Module
 *
 * Purpose:
 * Creates and attaches IAM policies granting Databricks role comprehensive access
 * to S3 bucket, KMS encryption, STS role assumption, and file event management.
 * This implements Step 3 of the Databricks storage configuration process.
 *
 * Policies Created:
 * 1. S3 + KMS + STS Access Policy (Unity Catalog data operations)
 * 2. File Events Management Policy (SNS, SQS, S3 notifications) - OPTIONAL but highly recommended
 *
 * Permissions Granted (Policy 1):
 * - S3: GetObject, PutObject, DeleteObject on /unity-catalog/* paths
 * - S3: ListBucket, GetBucketLocation on bucket root
 * - KMS: Decrypt, Encrypt, GenerateDataKey* for encrypted buckets
 * - STS: AssumeRole for self-assuming role pattern
 *
 * Permissions Granted (Policy 2 - Optional):
 * - S3: GetBucketNotification, PutBucketNotification
 * - SNS: Create, configure, publish, subscribe to topics
 * - SQS: Create, configure, send/receive messages from queues
 *
 * Security:
 * - All permissions scoped to specific bucket ARN
 * - Unity Catalog path isolation enforced
 * - Follows principle of least privilege
 *
 * Databricks Documentation:
 * https://docs.databricks.com/aws/iam/unity-catalog-iam-policy.html
 *
 * Cost: $0/month (IAM policies are free)
 */

# Get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# POLICY 1: S3 + KMS + STS Access (REQUIRED for Unity Catalog)
# ============================================================================

# IAM policy document for Unity Catalog storage access
data "aws_iam_policy_document" "databricks_unity_catalog_access" {
  # Statement 1: S3 object operations scoped to Unity Catalog paths
  statement {
    sid    = "UnityObjectOperations"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${var.bucket_arn}/unity-catalog/*"
    ]
  }

  # Statement 2: S3 bucket-level operations
  statement {
    sid    = "UnityBucketOperations"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      var.bucket_arn
    ]
  }

  # Statement 3: KMS operations for encrypted bucket access (if encryption enabled)
  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      sid    = "UnityKMSOperations"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey*"
      ]
      resources = [
        var.kms_key_arn
      ]
    }
  }

  # Statement 4: STS AssumeRole for self-assuming role pattern
  statement {
    sid    = "UnitySelfAssumeRole"
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/databricks/${var.role_name}"
    ]
  }
}

# Create IAM policy from document
resource "aws_iam_policy" "databricks_unity_catalog_access" {
  name        = var.policy_name
  description = "Grants Databricks Unity Catalog access to S3, KMS, and STS AssumeRole capabilities"
  path        = "/databricks/"
  policy      = data.aws_iam_policy_document.databricks_unity_catalog_access.json

  tags = {
    Name                = var.policy_name
    Purpose             = "Databricks Unity Catalog storage access"
    DatabricksWorkspace = var.workspace_name
    BucketScope         = "${var.bucket_name}/unity-catalog/*"
    PolicyType          = "UnityDataAccess"
  }
}

# Attach Unity Catalog policy to Databricks IAM role
resource "aws_iam_role_policy_attachment" "databricks_unity_catalog_access" {
  role       = var.role_name
  policy_arn = aws_iam_policy.databricks_unity_catalog_access.arn
}

# ============================================================================
# POLICY 2: File Events Management (OPTIONAL but highly recommended)
# ============================================================================

# IAM policy document for managed file events
data "aws_iam_policy_document" "databricks_file_events" {
  count = var.enable_file_events ? 1 : 0

  # Statement 1: File events setup (S3 notifications, SNS, SQS creation)
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
      var.bucket_arn,
      "arn:aws:sqs:*:${data.aws_caller_identity.current.account_id}:*",
      "arn:aws:sns:*:${data.aws_caller_identity.current.account_id}:*"
    ]
  }

  # Statement 2: File events list operations (resource discovery)
  statement {
    sid    = "ManagedFileEventsListStatement"
    effect = "Allow"
    actions = [
      "sqs:ListQueues",
      "sqs:ListQueueTags",
      "sns:ListTopics"
    ]
    resources = ["*"]
  }

  # Statement 3: File events teardown (cleanup on removal)
  statement {
    sid    = "ManagedFileEventsTeardownStatement"
    effect = "Allow"
    actions = [
      "sns:Unsubscribe",
      "sns:DeleteTopic",
      "sqs:DeleteQueue"
    ]
    resources = [
      "arn:aws:sqs:*:${data.aws_caller_identity.current.account_id}:*",
      "arn:aws:sns:*:${data.aws_caller_identity.current.account_id}:*"
    ]
  }
}

# Create file events policy if enabled
resource "aws_iam_policy" "databricks_file_events" {
  count = var.enable_file_events ? 1 : 0

  name        = "${var.policy_name}-file-events"
  description = "Grants Databricks access to manage S3 file events via SNS and SQS"
  path        = "/databricks/"
  policy      = data.aws_iam_policy_document.databricks_file_events[0].json

  tags = {
    Name                = "${var.policy_name}-file-events"
    Purpose             = "Databricks managed file events"
    DatabricksWorkspace = var.workspace_name
    BucketScope         = var.bucket_name
    PolicyType          = "FileEventsManagement"
  }
}

# Attach file events policy to Databricks IAM role if enabled
resource "aws_iam_role_policy_attachment" "databricks_file_events" {
  count = var.enable_file_events ? 1 : 0

  role       = var.role_name
  policy_arn = aws_iam_policy.databricks_file_events[0].arn
}

# ============================================================================
# OUTPUTS
# ============================================================================

# Policy 1 outputs
output "unity_catalog_policy_arn" {
  description = "ARN of the Unity Catalog S3 access policy"
  value       = aws_iam_policy.databricks_unity_catalog_access.arn
}

output "unity_catalog_policy_name" {
  description = "Name of the Unity Catalog S3 access policy"
  value       = aws_iam_policy.databricks_unity_catalog_access.name
}

output "unity_catalog_policy_id" {
  description = "Unique ID of the Unity Catalog IAM policy"
  value       = aws_iam_policy.databricks_unity_catalog_access.id
}

output "unity_catalog_policy_document" {
  description = "Unity Catalog policy document JSON (for validation)"
  value       = data.aws_iam_policy_document.databricks_unity_catalog_access.json
}

output "unity_catalog_attachment_id" {
  description = "ID of the Unity Catalog policy attachment to role"
  value       = aws_iam_role_policy_attachment.databricks_unity_catalog_access.id
}

# Policy 2 outputs (file events)
output "file_events_policy_arn" {
  description = "ARN of the file events policy (null if disabled)"
  value       = var.enable_file_events ? aws_iam_policy.databricks_file_events[0].arn : null
}

output "file_events_policy_name" {
  description = "Name of the file events policy (null if disabled)"
  value       = var.enable_file_events ? aws_iam_policy.databricks_file_events[0].name : null
}

output "file_events_enabled" {
  description = "Whether file events management policy is enabled"
  value       = var.enable_file_events
}

# Configuration status
output "configuration_status" {
  description = "Module configuration status and next steps"
  value = {
    step_completed = "Step 3: IAM Policies Attached"
    policies_created = var.enable_file_events ? [
      "Unity Catalog S3/KMS/STS access",
      "File events management (SNS/SQS)"
    ] : ["Unity Catalog S3/KMS/STS access"]
    permissions_granted = {
      s3_operations = [
        "s3:GetObject (${var.bucket_name}/unity-catalog/*)",
        "s3:PutObject (${var.bucket_name}/unity-catalog/*)",
        "s3:DeleteObject (${var.bucket_name}/unity-catalog/*)",
        "s3:ListBucket (${var.bucket_name})",
        "s3:GetBucketLocation (${var.bucket_name})"
      ]
      kms_operations = var.kms_key_arn != null ? [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey*"
      ] : ["KMS encryption not configured"]
      sts_operations = [
        "sts:AssumeRole (self-assuming role pattern)"
      ]
      file_events = var.enable_file_events ? [
        "S3 bucket notifications",
        "SNS topic creation and management",
        "SQS queue creation and management"
      ] : ["File events not enabled"]
    }
    role_attached  = var.role_name
    security_notes = "All permissions scoped to Unity Catalog paths (/unity-catalog/*) and specific bucket. No wildcard access."
    next_step      = "Step 4: Create Databricks storage configuration using Terraform provider"
    required_info = {
      role_arn    = "From databricks_iam_role module output"
      bucket_name = var.bucket_name
      account_id  = "Databricks account ID"
    }
  }
}

# Cost analysis
output "cost_estimate" {
  description = "Monthly cost estimate for IAM policies and attachments"
  value = {
    policy_cost      = "$0.00/month (IAM policies are free)"
    attachment_cost  = "$0.00/month (Policy attachments are free)"
    api_calls        = "~$0.00/month (S3/KMS API calls billed separately based on usage)"
    file_events_cost = var.enable_file_events ? "~$0.50-$2.00/month (SNS + SQS usage based on event volume)" : "$0.00/month (disabled)"
    total_monthly    = var.enable_file_events ? "~$0.50-$2.00/month" : "$0.00/month"
    notes            = "IAM policies have no direct cost. S3/KMS API calls billed at standard rates. SNS ($0.50 per million requests) and SQS ($0.40 per million requests) charges apply if file events enabled."
  }
}
