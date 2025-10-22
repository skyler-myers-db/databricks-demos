resource "aws_kms_key" "this" {
  description             = "Databricks CMK"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags = var.tags
}

resource "aws_kms_alias" "alias" {
  name          = var.kms_key_alias
  target_key_id = aws_kms_key.this.id
}

# Root bucket
resource "aws_s3_bucket" "root" {
  bucket        = var.root_bucket_name
  force_destroy = false
  tags          = merge(var.tags, { Name = var.root_bucket_name })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "root" {
  bucket = aws_s3_bucket.root.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "root" {
  bucket                  = aws_s3_bucket.root.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Log bucket
resource "aws_s3_bucket" "logs" {
  bucket        = var.log_bucket_name
  force_destroy = false
  tags          = merge(var.tags, { Name = var.log_bucket_name })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Strict bucket policies (enforce TLS and optional VPCE-only access)
data "aws_caller_identity" "current" {}

locals {
  tls_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "DenyInsecureTransport",
        Effect = "Deny",
        Principal = "*",
        Action = "s3:*",
        Resource = [
          "arn:aws:s3:::${var.root_bucket_name}",
          "arn:aws:s3:::${var.root_bucket_name}/*",
          "arn:aws:s3:::${var.log_bucket_name}",
          "arn:aws:s3:::${var.log_bucket_name}/*"
        ],
        Condition = {
          Bool = { "aws:SecureTransport" : "false" }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "root" {
  bucket = aws_s3_bucket.root.id
  policy = local.tls_policy
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = local.tls_policy
}

output "root_bucket"      { value = aws_s3_bucket.root.bucket }
output "root_bucket_arn"  { value = aws_s3_bucket.root.arn }
output "log_bucket"       { value = aws_s3_bucket.logs.bucket }
output "log_bucket_arn"   { value = aws_s3_bucket.logs.arn }
output "kms_key_arn"      { value = aws_kms_key.this.arn }
