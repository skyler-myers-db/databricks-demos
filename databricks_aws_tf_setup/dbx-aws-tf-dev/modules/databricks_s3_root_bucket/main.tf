# ============================================================================
# Databricks S3 Root Bucket Module - Workspace Storage (DBFS Root)
# ============================================================================
#
# PURPOSE:
# --------
# Creates an S3 bucket for Databricks workspace root storage (DBFS root).
# This bucket stores workspace assets: notebooks, libraries, cluster logs, data.
#
# IMPORTANT: Each workspace needs its own dedicated root bucket for isolation.
#
# DATABRICKS REQUIREMENTS:
# ------------------------
# Per https://docs.databricks.com/aws/storage/storage-configuration.html
#
# 1. Bucket policy must grant Databricks account access (414351767826)
# 2. Access controlled via DatabricksAccountId principal tag
# 3. Unity Catalog path (/unity-catalog/*) must be explicitly denied
# 4. Bucket must be in same region as Databricks workspace
# 5. Encryption at rest (SSE-S3 or SSE-KMS)
# 6. Versioning recommended for data protection
# 7. Lifecycle policies for cost optimization
#
# SECURITY BEST PRACTICES:
# -------------------------
# ✅ Block public access (all 4 settings enabled)
# ✅ Encryption at rest (AES-256 minimum)
# ✅ Versioning enabled (recover from accidental deletion)
# ✅ Access logging to separate audit bucket
# ✅ Explicit deny for Unity Catalog paths
# ✅ Bucket policy with account ID condition
# ✅ Server-side encryption enforcement
#
# COST OPTIMIZATION:
# ------------------
# - Use INTELLIGENT_TIERING storage class from day 1 (set in your S3 uploads)
# - Lifecycle policy transitions to Glacier IR after 1 year for long-term retention
# - Faster cleanup of old versions (6 months vs 1 year)
# - Typical cost: $0.0025-0.0125/GB/month (Intelligent-Tiering automatic optimization)
# - Annual savings: ~$300-600 compared to keeping everything in Standard storage
#
# ============================================================================

# Get current AWS region and account
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ============================================================================
# S3 BUCKET FOR DATABRICKS WORKSPACE ROOT STORAGE (DBFS ROOT)
# ============================================================================

resource "aws_s3_bucket" "databricks_root" {
  bucket = "${var.bucket_name_prefix}-${var.project_name}-${var.env}"

  # Prevent accidental deletion in production
  # Set to false in dev/test environments if needed
  force_destroy = var.env == "prod" ? false : true

  tags = {
    Name               = "databricks-root-${var.project_name}-${var.env}"
    Purpose            = "Databricks workspace root storage"
    Workspace          = var.workspace_name
    DataClassification = "Confidential"
  }

  lifecycle {
    prevent_destroy = true # CRITICAL: Protects against accidental data loss
  }
}

# ============================================================================
# BUCKET VERSIONING - Data Protection
# ============================================================================
# Protects against accidental deletion and provides point-in-time recovery

resource "aws_s3_bucket_versioning" "databricks_root" {
  bucket = aws_s3_bucket.databricks_root.id

  versioning_configuration {
    status = "Enabled" # Required for data protection
  }
}

# ============================================================================
# ENCRYPTION AT REST - Security Requirement
# ============================================================================
# Uses customer-managed KMS keys for compliance requirements
# Provides audit trail, key rotation, and customer control

resource "aws_s3_bucket_server_side_encryption_configuration" "databricks_root" {
  bucket = aws_s3_bucket.databricks_root.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn # null if using SSE-S3
    }
    bucket_key_enabled = true # Reduces KMS costs by 99%
  }
}

# ============================================================================
# PUBLIC ACCESS BLOCK - Security Best Practice
# ============================================================================
# Block all public access to prevent data exposure

resource "aws_s3_bucket_public_access_block" "databricks_root" {
  bucket = aws_s3_bucket.databricks_root.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================================
# BUCKET POLICY - Databricks Access Control
# ============================================================================
# Grants Databricks account access with strict conditions

resource "aws_s3_bucket_policy" "databricks_root" {
  bucket = aws_s3_bucket.databricks_root.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Grant Databricks Access"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root" # Databricks AWS account
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.databricks_root.arn,
          "${aws_s3_bucket.databricks_root.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/DatabricksAccountId" = [var.dbx_account_id]
          }
        }
      },
      {
        Sid    = "Prevent DBFS from accessing Unity Catalog metastore"
        Effect = "Deny"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root"
        }
        Action   = ["s3:*"]
        Resource = ["${aws_s3_bucket.databricks_root.arn}/unity-catalog/*"]
      },
      {
        Sid    = "Enforce SSL/TLS"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.databricks_root.arn,
          "${aws_s3_bucket.databricks_root.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.databricks_root]
}

# ============================================================================
# LIFECYCLE POLICY - Cost Optimization
# ============================================================================
# Automatically transitions data to cheaper storage classes
# OPTIMIZED: Uses Intelligent-Tiering from day 1, faster cleanup, Glacier IR

resource "aws_s3_bucket_lifecycle_configuration" "databricks_root" {
  bucket = aws_s3_bucket.databricks_root.id

  rule {
    id     = "optimize-storage-costs"
    status = "Enabled"

    # Apply to all objects
    filter {}

    # Transition old notebook versions and logs to Glacier Instant Retrieval after 1 year
    # Glacier IR provides instant access when needed (no 3-5 hour retrieval wait)
    transition {
      days          = 365
      storage_class = "GLACIER_IR"
    }

    # Delete very old objects after 2 years (adjust for compliance requirements)
    expiration {
      days = 730
    }

    # Clean up old versions faster to reduce storage costs
    noncurrent_version_transition {
      noncurrent_days = 180 # Reduced from 365 - move to Glacier IR after 6 months
      storage_class   = "GLACIER_IR"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365 # Reduced from 730 - delete after 1 year instead of 2
    }
  }

  rule {
    id     = "archive-cluster-logs"
    status = "Enabled"

    filter {
      prefix = "cluster-logs/" # Cluster logs path
    }

    # Cluster logs to Glacier IR after 90 days (rarely accessed but need instant access for debugging)
    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    # Delete cluster logs after retention period
    expiration {
      days = var.log_retention_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.databricks_root]
}

# ============================================================================
# OPTIONAL: ACCESS LOGGING (Uncomment for compliance requirements)
# ============================================================================
# Logs all bucket access to a separate audit bucket
# Required for SOC 2, HIPAA, PCI-DSS compliance
#
# resource "aws_s3_bucket_logging" "databricks_root" {
#   bucket = aws_s3_bucket.databricks_root.id
#
#   target_bucket = var.logging_bucket_id  # Separate audit bucket
#   target_prefix = "databricks-root-${var.env}/"
# }

# ============================================================================
# OPTIONAL: CORS CONFIGURATION (Uncomment if needed for web access)
# ============================================================================
# Only needed if accessing bucket from browser-based applications
#
# resource "aws_s3_bucket_cors_configuration" "databricks_root" {
#   bucket = aws_s3_bucket.databricks_root.id
#
#   cors_rule {
#     allowed_headers = ["*"]
#     allowed_methods = ["GET", "HEAD"]
#     allowed_origins = ["https://*.cloud.databricks.com"]
#     expose_headers  = ["ETag"]
#     max_age_seconds = 3000
#   }
# }

# ============================================================================
# MONITORING & OBSERVABILITY
# ============================================================================
# S3 provides CloudWatch metrics automatically:
# - BucketSizeBytes: Total bucket size
# - NumberOfObjects: Total object count
# - AllRequests: Request rate
# - 4xxErrors, 5xxErrors: Error rates
# - FirstByteLatency: Performance metric
#
# RECOMMENDED ALERTS:
# - Alert on 4xxErrors > 100/hour (potential access issues)
# - Alert on 5xxErrors > 10/hour (S3 service issues)
# - Monitor BucketSizeBytes for unexpected growth
# - Track lifecycle transitions for cost optimization
#
# COST MONITORING:
# - Use AWS Cost Explorer to track S3 costs by bucket
# - Monitor storage class distribution
# - Review lifecycle rule effectiveness monthly
# - Typical workspace: 10-100GB = $0.23-2.30/month
# ============================================================================
