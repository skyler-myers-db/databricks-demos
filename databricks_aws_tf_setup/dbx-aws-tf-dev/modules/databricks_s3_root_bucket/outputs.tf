# ============================================================================
# S3 BUCKET OUTPUTS
# ============================================================================

output "bucket_id" {
  description = "The ID (name) of the Databricks root storage bucket"
  value       = aws_s3_bucket.databricks_root.id
}

output "bucket_arn" {
  description = "The ARN of the Databricks root storage bucket"
  value       = aws_s3_bucket.databricks_root.arn
}

output "bucket_name" {
  description = "The name of the Databricks root storage bucket"
  value       = aws_s3_bucket.databricks_root.bucket
}

output "bucket_region" {
  description = "The AWS region where the bucket was created"
  value       = aws_s3_bucket.databricks_root.region
}

output "bucket_domain_name" {
  description = "The bucket domain name (for SDK/CLI access)"
  value       = aws_s3_bucket.databricks_root.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket regional domain name (for SDK/CLI access)"
  value       = aws_s3_bucket.databricks_root.bucket_regional_domain_name
}

# ============================================================================
# CONFIGURATION OUTPUTS (For Databricks Workspace Creation)
# ============================================================================

output "storage_configuration_name" {
  description = "Recommended name for Databricks storage configuration"
  value       = "${var.project_name}-${var.env}-storage"
}

output "databricks_workspace_url" {
  description = "Expected Databricks workspace URL pattern (actual URL assigned after workspace creation)"
  value       = "https://<workspace-id>.cloud.databricks.com"
}

# ============================================================================
# SECURITY & COMPLIANCE OUTPUTS
# ============================================================================

output "encryption_status" {
  description = "Bucket encryption configuration"
  value = {
    enabled   = true
    algorithm = "AES256"
    type      = "SSE-S3 (AWS Managed Keys)"
  }
}

output "versioning_status" {
  description = "Bucket versioning status"
  value       = "Enabled"
}

output "public_access_block_status" {
  description = "Public access block configuration"
  value = {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
}

output "compliance_features" {
  description = "Compliance features enabled on the bucket"
  value = {
    encryption_at_rest      = "✅ AES-256"
    versioning              = "✅ Enabled"
    public_access_blocked   = "✅ All 4 settings enabled"
    ssl_enforcement         = "✅ Required (bucket policy)"
    unity_catalog_isolation = "✅ Explicit deny for /unity-catalog/*"
    lifecycle_management    = "✅ Cost optimization enabled"
  }
}

# ============================================================================
# COST ESTIMATION
# ============================================================================

output "estimated_monthly_cost" {
  description = "Estimated monthly storage cost (excludes data transfer)"
  value = {
    storage_standard        = "$0.023/GB/month (first 30 days)"
    storage_intelligent     = "$0.0025-0.0125/GB/month (after 30 days)"
    typical_10gb_workspace  = "~$0.23-0.30/month"
    typical_100gb_workspace = "~$2.30-3.00/month"
    requests                = "$0.005/1000 PUT + $0.0004/1000 GET"
    data_transfer_out       = "$0.09/GB (first 10TB)"
  }
}

# ============================================================================
# NEXT STEPS OUTPUT
# ============================================================================

output "next_steps" {
  description = "Instructions for completing Databricks storage configuration"
  value = {
    step_1 = "✅ S3 bucket created with proper permissions"
    step_2 = "Create IAM role with AssumeRole trust policy for Databricks"
    step_3 = "Attach IAM policy to role allowing access to this S3 bucket"
    step_4 = "Create Databricks storage configuration via API or Terraform"
    step_5 = "Create network configuration (VPC, subnets, security groups)"
    step_6 = "Create Databricks workspace using storage + network configs"

    bucket_name_for_iam_policy = aws_s3_bucket.databricks_root.id
    bucket_arn_for_iam_policy  = aws_s3_bucket.databricks_root.arn
  }
}
