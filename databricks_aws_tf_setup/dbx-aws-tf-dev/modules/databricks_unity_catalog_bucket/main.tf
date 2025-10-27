# ============================================================================
# UNITY CATALOG STORAGE BUCKET
# ============================================================================
# Purpose: S3 bucket for Unity Catalog managed table storage
# Stores: Catalog data, managed tables, checkpoints, temporary files
# Encryption: Server-side encryption with customer-managed KMS key
# ============================================================================

resource "aws_s3_bucket" "unity_catalog" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(
    var.aws_tags,
    {
      Name    = var.bucket_name
      Purpose = "databricks-unity-catalog-storage"
      Project = var.project_name
      Env     = var.env
    }
  )
}

# ============================================================================
# BUCKET ENCRYPTION
# ============================================================================
resource "aws_s3_bucket_server_side_encryption_configuration" "unity_catalog" {
  bucket = aws_s3_bucket.unity_catalog.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# ============================================================================
# BUCKET VERSIONING
# ============================================================================
resource "aws_s3_bucket_versioning" "unity_catalog" {
  bucket = aws_s3_bucket.unity_catalog.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================================================
# PUBLIC ACCESS BLOCK
# ============================================================================
resource "aws_s3_bucket_public_access_block" "unity_catalog" {
  bucket = aws_s3_bucket.unity_catalog.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================================
# LIFECYCLE RULES
# ============================================================================
resource "aws_s3_bucket_lifecycle_configuration" "unity_catalog" {
  bucket = aws_s3_bucket.unity_catalog.id

  # Abort incomplete multipart uploads after 7 days
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Transition old versions to cheaper storage
  rule {
    id     = "transition-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER_IR"
    }
  }

  # Delete old versions after 180 days
  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }
}

# ============================================================================
# BUCKET POLICY - Databricks Access
# ============================================================================
locals {
  unity_catalog_role_arn = "arn:aws:iam::${var.aws_account_id}:role/${var.project_name}-${var.env}-unity-catalog-storage-role"
}

resource "aws_s3_bucket_policy" "unity_catalog" {
  bucket = aws_s3_bucket.unity_catalog.id
  policy = data.aws_iam_policy_document.unity_catalog_bucket.json
}

data "aws_iam_policy_document" "unity_catalog_bucket" {
  # Allow Databricks account to access the bucket
  statement {
    sid    = "DatabricksUnityAccessBucket"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"]
    }
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      aws_s3_bucket.unity_catalog.arn,
      "${aws_s3_bucket.unity_catalog.arn}/*"
    ]
  }

  # Allow customer IAM role used by storage credential to access the bucket
  statement {
    sid    = "UnityCatalogRoleBucketAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.unity_catalog_role_arn]
    }
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketNotification",
      "s3:PutBucketNotification",
      "s3:ListBucketMultipartUploads"
    ]
    resources = [
      aws_s3_bucket.unity_catalog.arn
    ]
  }

  statement {
    sid    = "UnityCatalogRoleObjectAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.unity_catalog_role_arn]
    }
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = [
      "${aws_s3_bucket.unity_catalog.arn}/*"
    ]
  }

  # Require encryption in transit
  statement {
    sid    = "RequireEncryptionInTransit"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.unity_catalog.arn,
      "${aws_s3_bucket.unity_catalog.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}
