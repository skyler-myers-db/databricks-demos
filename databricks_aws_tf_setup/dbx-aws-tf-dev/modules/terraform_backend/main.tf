# ============================================================================
# Terraform Backend Module - S3 + DynamoDB for Remote State
# ============================================================================
# Purpose: Create infrastructure for Terraform remote state storage
# Cost: ~$0.50/month
#
# This module creates the backend infrastructure as part of the main
# infrastructure deployment. After first successful apply, you can migrate
# from local state to S3 remote state.
#
# WORKFLOW:
# 1. terraform apply (creates all infrastructure including backend)
# 2. Copy backend config from output
# 3. Add to versions.tf
# 4. terraform init -migrate-state (migrates local → S3)
# 5. Done! All future applies use remote state
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# S3 BUCKET FOR TERRAFORM STATE
# ============================================================================
resource "aws_s3_bucket" "terraform_state" {
  bucket = "databricks-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Terraform State - ${var.project_name}-${var.env}"
    Purpose     = "Terraform remote state storage"
    Environment = var.env
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# Enable versioning (disaster recovery)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy (move old versions to Glacier)
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "archive-old-state-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# ============================================================================
# DYNAMODB TABLE FOR STATE LOCKING
# ============================================================================
resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "databricks-terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "Terraform State Lock - ${var.project_name}-${var.env}"
    Purpose     = "Terraform state locking"
    Environment = var.env
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================
output "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "S3 bucket ARN for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.terraform_state_lock.name
}

output "backend_configuration" {
  description = "Backend configuration to add to versions.tf"
  value       = <<-EOT

    ============================================================================
    STEP 3: Add this backend configuration to versions.tf:
    ============================================================================

    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "databricks/${var.env}/terraform.tfstate"
        region         = "${data.aws_region.current.id}"
        encrypt        = true
        dynamodb_table = "${aws_dynamodb_table.terraform_state_lock.name}"
      }
    }

    ============================================================================
    STEP 4: Migrate local state to S3:
    ============================================================================

    terraform init -migrate-state

    Answer "yes" when prompted to copy existing state to S3.

    ============================================================================
    STEP 5: Verify state is now remote:
    ============================================================================

    aws s3 ls s3://${aws_s3_bucket.terraform_state.id}/databricks/${var.env}/

    You should see: terraform.tfstate

    Local terraform.tfstate file will become a stub pointing to remote state.

    ============================================================================
  EOT
}
