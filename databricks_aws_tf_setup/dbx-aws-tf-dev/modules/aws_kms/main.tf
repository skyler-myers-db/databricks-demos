# ============================================================================
# AWS KMS Key Module - S3 Encryption for Databricks
# ============================================================================
# Purpose: Creates customer-managed KMS key for S3 bucket encryption
# Required for: Compliance (HIPAA, PCI-DSS, SOC 2 Type II)
# Cost: ~$1/month per key + $0.03 per 10,000 requests
#
# BENEFITS:
# - Customer control over encryption keys
# - Key rotation (automatic, annual)
# - Audit trail (CloudTrail logs all key usage)
# - Compliance requirement for many frameworks
# - Granular access control
#
# vs SSE-S3:
# - SSE-S3: AWS-managed keys, free, good for most use cases
# - KMS: Customer-managed keys, $1/mo, required for compliance
# ============================================================================

# ============================================================================
# KMS KEY FOR DATABRICKS S3 BUCKET ENCRYPTION
# ============================================================================
resource "aws_kms_key" "databricks_s3" {
  description             = "KMS key for Databricks S3 bucket encryption (${var.project_name}-${var.env})"
  deletion_window_in_days = 30   # Recovery period if accidentally deleted
  enable_key_rotation     = true # Automatic annual rotation

  tags = {
    Name        = "databricks-s3-${var.project_name}-${var.env}"
    Purpose     = "S3 bucket encryption for Databricks workspace"
    Environment = var.env
    Project     = var.project_name
  }
}

# ============================================================================
# KMS KEY ALIAS - Friendly Name
# ============================================================================
resource "aws_kms_alias" "databricks_s3" {
  name          = "alias/databricks-s3-${var.project_name}-${var.env}"
  target_key_id = aws_kms_key.databricks_s3.key_id
}

# ============================================================================
# KMS KEY POLICY - Access Control
# ============================================================================
resource "aws_kms_key_policy" "databricks_s3" {
  key_id = aws_kms_key.databricks_s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Statement 1: Root account has full control (required)
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # Statement 2: Allow Databricks role to use key
      {
        Sid    = "Allow Databricks Role to Use Key"
        Effect = "Allow"
        Principal = {
          AWS = var.databricks_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      # Statement 3: Allow S3 service to use key
      {
        Sid    = "Allow S3 Service to Use Key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${data.aws_region.current.id}.amazonaws.com"
          }
        }
      },
      # Statement 4: Allow CloudWatch Logs to use key (for VPC Flow Logs)
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.id}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })
}

# ============================================================================
# DATA SOURCES
# ============================================================================
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# OUTPUTS
# ============================================================================
output "kms_key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.databricks_s3.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN (use this for S3 bucket encryption)"
  value       = aws_kms_key.databricks_s3.arn
}

output "kms_alias_name" {
  description = "KMS key alias name"
  value       = aws_kms_alias.databricks_s3.name
}

output "kms_alias_arn" {
  description = "KMS key alias ARN"
  value       = aws_kms_alias.databricks_s3.arn
}

# ============================================================================
# USAGE NOTES
# ============================================================================
# This KMS key can be used for:
# - S3 bucket encryption (primary use)
# - CloudWatch Logs encryption (VPC Flow Logs)
# - Any other Databricks-related encrypted data
#
# Cost: ~$1/month per key + $0.03 per 10,000 requests
# Typical usage: <10,000 requests/month = ~$1.00-1.30/month total
#
# Key Rotation:
# - Automatic annual rotation enabled
# - Old keys retained for decryption of existing data
# - No application changes needed
#
# Compliance:
# - Meets HIPAA, PCI-DSS, SOC 2 requirements
# - CloudTrail logs all key usage for audit
# - Customer-managed = you control the keys
# ============================================================================
