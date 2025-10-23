# ============================================================================
# ROOT MODULE - Databricks AWS Infrastructure with Modular Architecture
# ============================================================================
#
# ARCHITECTURE OVERVIEW:
# ----------------------
# This root module orchestrates the creation of a production-ready Databricks
# environment on AWS Premium tier with proper network segmentation, high
# availability, and security best practices.
#
# MODULE DEPENDENCY FLOW:
# -----------------------
# 1. aws_account         → Creates AWS account in organization
# 2. aws_vpc             → Creates VPC with flow logs and DNS
# 3. aws_subnets         → Creates private/public subnets (depends on VPC)
# 4. aws_internet_gateway→ Creates IGW (depends on VPC)
# 5. aws_nat_gateway     → Creates NAT GW with EIPs (depends on IGW, subnets)
# 6. aws_route_tables    → Creates route tables (depends on IGW, NAT, subnets)
# 7. aws_security_groups → Creates SGs for Databricks & endpoints (depends on VPC, subnets)
# 8. aws_vpc_endpoints   → Creates endpoints (depends on SGs, route tables, subnets)
# 9. aws_network_acls    → Creates NACLs (depends on VPC, subnets) - Databricks required
#
# MODERN BEST PRACTICES (Oct 2025):
# ----------------------------------
# ✅ Granular modules (single responsibility principle)
# ✅ Explicit dependencies (predictable apply order)
# ✅ Comprehensive documentation (in-line architecture notes)
# ✅ Cost transparency (per-resource cost estimates)
# ✅ Enterprise tier ready (PrivateLink notes throughout)
# ✅ High availability (multi-AZ by default)
# ✅ Security first (least privilege, defense in depth)
# ✅ Observable (flow logs, CloudWatch integration)
#
# ============================================================================

# Step 1: Create the AWS account in your organization
# Uses root account provider
module "aws_account" {
  source = "./modules/aws_account"

  providers = {
    aws = aws.root
  }

  project_name  = var.project_name
  env           = var.env
  account_email = var.account_email
  parent_ou_id  = var.parent_ou_id
  tags          = var.aws_tags
}

# ============================================================================
# MODULAR NETWORKING INFRASTRUCTURE
# ============================================================================
# Replaces monolithic networking module with granular, maintainable components
# Each module handles a specific AWS resource type with clear boundaries

# Step 2: Create VPC with flow logs and security monitoring
module "vpc" {
  source = "./modules/aws_vpc"

  providers = {
    aws = aws.dev
  }

  vpc_cidr_block           = var.vpc_cidr_block
  project_name             = var.project_name
  env                      = var.env
  flow_logs_retention_days = 7 # Use 30-90 for production

  depends_on = [module.aws_account]
}

# Step 3: Create private and public subnets across multiple AZs
module "subnets" {
  source = "./modules/aws_subnets"

  providers = {
    aws = aws.dev
  }

  vpc_id                 = module.vpc.vpc_id
  vpc_cidr_block         = module.vpc.vpc_cidr_block
  availability_zones     = module.vpc.availability_zones
  subnet_count           = var.subnet_count
  private_subnet_newbits = var.private_subnet_newbits
  public_subnet_newbits  = var.public_subnet_newbits
  project_name           = var.project_name
  env                    = var.env
}

# Step 4: Create Internet Gateway for public subnet connectivity
module "internet_gateway" {
  source = "./modules/aws_internet_gateway"

  providers = {
    aws = aws.dev
  }

  vpc_id       = module.vpc.vpc_id
  project_name = var.project_name
  env          = var.env
}

# Step 5: Create NAT Gateways with Elastic IPs (one per AZ for HA)
module "nat_gateway" {
  source = "./modules/aws_nat_gateway"

  providers = {
    aws = aws.dev
  }

  subnet_count        = var.subnet_count
  public_subnet_ids   = module.subnets.public_subnet_ids
  availability_zones  = module.subnets.public_subnet_availability_zones
  internet_gateway_id = module.internet_gateway.internet_gateway_id
  project_name        = var.project_name
  env                 = var.env
}

# Step 6: Create route tables with proper routing for public/private subnets
module "route_tables" {
  source = "./modules/aws_route_tables"

  providers = {
    aws = aws.dev
  }

  vpc_id              = module.vpc.vpc_id
  subnet_count        = var.subnet_count
  private_subnet_ids  = module.subnets.private_subnet_ids
  public_subnet_ids   = module.subnets.public_subnet_ids
  internet_gateway_id = module.internet_gateway.internet_gateway_id
  nat_gateway_ids     = module.nat_gateway.nat_gateway_ids
  availability_zones  = module.subnets.private_subnet_availability_zones
  project_name        = var.project_name
  env                 = var.env
}

# Step 7: Create security groups for VPC endpoints
module "security_groups" {
  source = "./modules/aws_security_groups"

  providers = {
    aws = aws.dev
  }

  vpc_id               = module.vpc.vpc_id
  private_subnet_cidrs = module.subnets.private_subnet_cidrs
  availability_zones   = module.subnets.private_subnet_availability_zones
  project_name         = var.project_name
  env                  = var.env
}

# Step 8: Create VPC endpoints for private AWS service connectivity
module "vpc_endpoints" {
  source = "./modules/aws_vpc_endpoints"

  providers = {
    aws = aws.dev
  }

  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.subnets.private_subnet_ids
  private_route_table_ids = module.route_tables.private_route_table_ids_for_endpoints
  security_group_ids      = module.security_groups.vpc_endpoint_security_group_ids
  project_name            = var.project_name
  env                     = var.env

  # Optional endpoints (EC2, Glue, Secrets Manager, KMS, CloudWatch Logs, PrivateLink):
  # - EC2 endpoint is enabled by default (comment out in module to disable)
  # - For other endpoints, uncomment resource blocks in the module's main.tf
  # - Each interface endpoint costs $7.20/month per AZ whether used or not
}

# Step 9: Create Network ACLs for Databricks Premium tier compliance
module "network_acls" {
  source = "./modules/aws_network_acls"

  providers = {
    aws = aws.dev
  }

  vpc_id             = module.vpc.vpc_id
  vpc_cidr_block     = module.vpc.vpc_cidr_block
  private_subnet_ids = module.subnets.private_subnet_ids
  public_subnet_ids  = module.subnets.public_subnet_ids
  project_name       = var.project_name
  env                = var.env

  # Network ACLs implement Databricks Premium tier requirements:
  # - Ingress: ALLOW ALL from 0.0.0.0/0 (Databricks control plane requirement)
  # - Egress: Specific ports (443, 3306, 53, 6666, 8443, 8444, 8445-8451)
  # - Stateless filtering (defense-in-depth with Security Groups)
  # - FREE (no cost for NACLs or rules)
}

# ============================================================================
# DATABRICKS WORKSPACE RESOURCES
# ============================================================================

# Step 10: Create S3 root bucket for Databricks workspace storage (DBFS root)
module "databricks_s3_root" {
  source = "./modules/databricks_s3_root_bucket"

  providers = {
    aws = aws.dev
  }

  project_name       = var.project_name
  env                = var.env
  workspace_name     = "${var.project_name}-${var.env}-workspace"
  dbx_account_id     = var.dbx_account_id
  log_retention_days = 365 # Cluster logs retention (1 year)

  # Bucket naming: databricks-workspace-<project>-<env>
  # Example: databricks-workspace-myproject-dev
}

# Step 11: Create IAM role for Databricks cross-account S3 access
module "databricks_iam_role" {
  source = "./modules/databricks_iam_role"

  providers = {
    aws = aws.dev
  }

  role_name      = "${var.project_name}-${var.env}-databricks-storage"
  project_name   = var.project_name
  env            = var.env
  workspace_name = "${var.project_name}-${var.env}-workspace"
  dbx_account_id = var.dbx_account_id

  # Trust policy allows:
  # - Databricks Unity Catalog role (414351767826)
  # - Self-assuming pattern for credential renewal
  # - External ID condition with Databricks account ID
}

# Step 12: Attach comprehensive IAM policies to Databricks role (Step 3 requirements)
module "databricks_iam_policy" {
  source = "./modules/databricks_iam_policy"

  providers = {
    aws = aws.dev
  }

  # Dependency: Wait for IAM role and S3 bucket to be created
  depends_on = [module.databricks_iam_role, module.databricks_s3_root]

  policy_name    = "${var.project_name}-${var.env}-databricks-unity-catalog"
  role_name      = module.databricks_iam_role.role_name
  bucket_arn     = module.databricks_s3_root.bucket_arn
  bucket_name    = module.databricks_s3_root.bucket_name
  workspace_name = "${var.project_name}-${var.env}-workspace"
  project_name   = var.project_name
  env            = var.env

  # KMS encryption (set to null if using SSE-S3)
  kms_key_arn = null # Change to KMS key ARN if bucket uses KMS encryption

  # File events management (highly recommended by Databricks)
  enable_file_events = true

  # Comprehensive permissions per Databricks Step 3:
  # Policy 1 (Unity Catalog): S3 (/unity-catalog/* paths), KMS (if enabled), STS (self-assuming)
  # Policy 2 (File Events): S3 notifications, SNS topic mgmt, SQS queue mgmt
}
