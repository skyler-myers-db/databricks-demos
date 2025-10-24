# ============================================================================
# Root Module Outputs
# ============================================================================
# Purpose: Expose all critical infrastructure outputs for post-deployment use
# Usage: terraform output <output_name>
# ============================================================================

# ============================================================================
# Networking Outputs
# ============================================================================
output "vpc_id" {
  description = "VPC ID for Databricks workspace"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs (Databricks clusters deployed here)"
  value       = module.subnets.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs (NAT Gateways only)"
  value       = module.subnets.public_subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs (one per AZ for high availability)"
  value       = module.nat_gateway.nat_gateway_ids
}

output "security_group_id" {
  description = "Security group ID for Databricks clusters"
  value       = module.security_groups.databricks_workspace_security_group_id
}

# ============================================================================
# Storage Outputs
# ============================================================================
output "s3_root_bucket_name" {
  description = "S3 root bucket for Databricks workspace storage"
  value       = module.databricks_s3_root.bucket_name
}

output "s3_root_bucket_arn" {
  description = "S3 root bucket ARN"
  value       = module.databricks_s3_root.bucket_arn
}

# ============================================================================
# IAM Outputs
# ============================================================================
output "cross_account_role_arn" {
  description = "IAM role ARN for Databricks cross-account access"
  value       = module.databricks_iam_role.role_arn
}

output "cross_account_role_name" {
  description = "IAM role name"
  value       = module.databricks_iam_role.role_name
}

output "external_id" {
  description = "External ID for IAM role trust policy (prevents confused deputy attacks)"
  value       = var.dbx_account_id
  sensitive   = true
}

# ============================================================================
# Databricks Account Configuration Outputs
# ============================================================================
output "storage_configuration_id" {
  description = "Databricks storage configuration ID (MWS)"
  value       = module.databricks_storage_config.storage_configuration_id
}

output "credentials_id" {
  description = "Databricks credentials configuration ID (MWS)"
  value       = module.databricks_storage_config.credentials_id
}

output "network_configuration_id" {
  description = "Databricks network configuration ID (MWS)"
  value       = module.databricks_network_config.network_id
}

# ============================================================================
# Unity Catalog Outputs
# ============================================================================
output "metastore_id" {
  description = "Unity Catalog metastore ID (shared across workspaces in region)"
  value       = module.databricks_metastore.metastore_id
}

output "metastore_name" {
  description = "Unity Catalog metastore name"
  value       = module.databricks_metastore.metastore_name
}

output "metastore_region" {
  description = "AWS region for metastore (must match workspace region)"
  value       = module.databricks_metastore.metastore_region
}

output "metastore_storage_model" {
  description = "Metastore storage model explanation"
  value       = "Metastore created WITHOUT storage_root (modern best practice). Each catalog must have MANAGED LOCATION 's3://bucket/catalog/'. Metadata stored in Databricks control plane ($0 cost)."
}

# ============================================================================
# Workspace Outputs
# ============================================================================
output "workspace_id" {
  description = "Databricks workspace ID (numeric)"
  value       = module.databricks_workspace.workspace_id
}

output "workspace_url" {
  description = "Databricks workspace URL (login here)"
  value       = module.databricks_workspace.workspace_url
}

output "workspace_name" {
  description = "Databricks workspace display name"
  value       = module.databricks_workspace.workspace_name
}

output "deployment_name" {
  description = "Databricks deployment name (globally unique identifier)"
  value       = module.databricks_workspace.deployment_name
}

output "workspace_status" {
  description = "Workspace provisioning status (RUNNING, PROVISIONING, FAILED)"
  value       = module.databricks_workspace.workspace_status
}

output "pricing_tier" {
  description = "Databricks pricing tier (PREMIUM for Unity Catalog and RBAC)"
  value       = module.databricks_workspace.pricing_tier
}

# ============================================================================
# Quick Start Output
# ============================================================================
output "quick_start_guide" {
  description = "Quick start instructions for post-deployment"
  value       = <<-EOT
    ================================================================================
    🎉 DATABRICKS WORKSPACE DEPLOYMENT SUCCESSFUL
    ================================================================================

    📍 WORKSPACE ACCESS
    -------------------
    URL: ${module.databricks_workspace.workspace_url}
    Workspace ID: ${module.databricks_workspace.workspace_id}
    Deployment: ${coalesce(module.databricks_workspace.deployment_name, "auto-generated")}
    Status: ${module.databricks_workspace.workspace_status}
    Region: ${var.aws_region}
    Tier: ${module.databricks_workspace.pricing_tier}

    🔐 UNITY CATALOG
    ----------------
    Metastore ID: ${module.databricks_metastore.metastore_id}
    Metastore: ${module.databricks_metastore.metastore_name}
    Storage Model: Metastore WITHOUT storage_root (modern best practice)

    🌐 NETWORKING
    -------------
    VPC: ${module.vpc.vpc_id} (${module.vpc.vpc_cidr_block})
    Private Subnets: ${length(module.subnets.private_subnet_ids)} subnets across ${length(module.subnets.private_subnet_ids)} AZs
    NAT Gateways: ${length(module.nat_gateway.nat_gateway_ids)} (high availability)
    Security Group: ${module.security_groups.databricks_workspace_security_group_id}

    💾 STORAGE
    ----------
    S3 Root Bucket: ${module.databricks_s3_root.bucket_name}
    Encryption: SSE-S3 (AES-256, AWS-managed)
    IAM Role: ${module.databricks_iam_role.role_arn}

    ================================================================================
    📝 NEXT STEPS
    ================================================================================

    1️⃣  LOGIN TO WORKSPACE
        Navigate to: ${module.databricks_workspace.workspace_url}
        Use account admin credentials (first login takes 2-3 minutes)

    2️⃣  CREATE UNITY CATALOG STRUCTURE
        SQL Editor → Run:

        -- Create main catalog with managed location
        CREATE CATALOG main
        MANAGED LOCATION 's3://${module.databricks_s3_root.bucket_name}/catalogs/main/';

        -- Create schemas (Bronze/Silver/Gold)
        CREATE SCHEMA main.bronze;
        CREATE SCHEMA main.silver;
        CREATE SCHEMA main.gold;

        -- Grant permissions
        GRANT USE CATALOG ON main TO `account users`;
        GRANT USE SCHEMA ON ALL SCHEMAS IN CATALOG main TO `account users`;

    3️⃣  CREATE FIRST CLUSTER
        Compute → Create Cluster:
        - Name: analytics-cluster
        - Runtime: 14.3 LTS (latest)
        - Node Type: m5.xlarge
        - Min Workers: 1, Max Workers: 8
        - Auto-termination: 30 minutes
        - Mode: Single User (or Shared for Premium)

    4️⃣  RUN FIRST QUERY
        SQL Editor → New Query:

        SELECT current_catalog(), current_schema(), current_user();

        -- Should return: main | default | <your-email>

    5️⃣  CONFIGURE WORKSPACE SETTINGS
        Admin Console → Workspace Settings:
        ✅ Enable audit logs
        ✅ Enable token tracking
        ✅ Enable workspace analytics
        ✅ Set cluster policies (restrict instance types)

    ================================================================================
    📊 COST MONITORING
    ================================================================================

    Fixed Monthly Costs:
    - NAT Gateways (${length(module.nat_gateway.nat_gateway_ids)}×): ~$${32.85 * length(module.nat_gateway.nat_gateway_ids)}/month
    - VPC Endpoints (2×): ~$14/month
    - S3 Storage: ~$23/TB/month

    Variable Costs (Databricks DBUs):
    - Jobs Compute: $0.15/DBU
    - All-Purpose Compute: $0.55/DBU
    - SQL Compute: $0.22/DBU

    💡 TIP: Set auto-termination to 15-30 minutes to minimize idle costs

    ================================================================================
    📚 DOCUMENTATION
    ================================================================================

    - Complete Setup: COMPLETE_SETUP_SUMMARY.md
    - Architecture: ARCHITECTURE.md
    - Cross-Account Setup: CROSS_ACCOUNT_SETUP.md
    - Deployment Steps: DEPLOYMENT_STEPS.md
    - Databricks Docs: https://docs.databricks.com/

    ================================================================================
    🔧 TROUBLESHOOTING
    ================================================================================

    If workspace not accessible:
    → terraform output workspace_status (should be RUNNING)
    → Check security groups allow 443, 8443-8451
    → Verify NAT Gateways are active

    If Unity Catalog not visible:
    → Ensure user has account admin role
    → Check data access configuration

    If clusters won't start:
    → Verify IAM role has 52 EC2 actions
    → Check subnet IP availability (need 50+ IPs)
    → Ensure NAT Gateways are functional

    Need help? Review documentation files above or contact Databricks support.

    ================================================================================
    🚀 HAPPY DATA ENGINEERING!
    ================================================================================
  EOT
}

# ============================================================================
# Infrastructure Summary Output
# ============================================================================
output "infrastructure_summary" {
  description = "Summary of all deployed infrastructure"
  value = {
    # Networking
    vpc_id          = module.vpc.vpc_id
    vpc_cidr        = module.vpc.vpc_cidr_block
    private_subnets = module.subnets.private_subnet_ids
    public_subnets  = module.subnets.public_subnet_ids
    nat_gateways    = module.nat_gateway.nat_gateway_ids
    security_group  = module.security_groups.databricks_workspace_security_group_id

    # Storage
    s3_bucket    = module.databricks_s3_root.bucket_name
    iam_role_arn = module.databricks_iam_role.role_arn

    # Databricks
    storage_config_id = module.databricks_storage_config.storage_configuration_id
    credentials_id    = module.databricks_storage_config.credentials_id
    network_config_id = module.databricks_network_config.network_id
    metastore_id      = module.databricks_metastore.metastore_id
    workspace_id      = module.databricks_workspace.workspace_id
    workspace_url     = module.databricks_workspace.workspace_url
    workspace_status  = module.databricks_workspace.workspace_status

    # Configuration
    region       = var.aws_region
    pricing_tier = module.databricks_workspace.pricing_tier
  }
}

# ============================================================================
# Terraform Backend Setup
# ============================================================================
output "migrate_to_remote_state" {
  description = "Instructions for migrating to S3 remote state"
  value       = module.terraform_backend.backend_configuration
}

data "aws_caller_identity" "current" {}

# ============================================================================
# Identity Center Outputs (Phase 2 - Optional)
# ============================================================================
# Uncomment after enabling identity_center module in main.tf

# output "identity_center_scim_token" {
#   description = "SCIM token for AWS IAM Identity Center (SENSITIVE - use for AWS console setup)"
#   value       = module.identity_center.scim_token
#   sensitive   = true
# }
#
# output "identity_center_scim_endpoint" {
#   description = "SCIM endpoint URL for AWS IAM Identity Center configuration"
#   value       = module.identity_center.scim_endpoint
# }
#
# output "identity_center_data_engineers_group_id" {
#   description = "ID of the data_engineers group in Databricks"
#   value       = module.identity_center.data_engineers_group_id
# }
#
# output "identity_center_next_steps" {
#   description = "Instructions for completing SCIM setup in AWS IAM Identity Center"
#   value       = module.identity_center.next_steps
# }

