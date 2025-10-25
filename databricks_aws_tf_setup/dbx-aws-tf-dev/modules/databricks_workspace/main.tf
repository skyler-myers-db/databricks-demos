# ============================================================================
# Databricks Workspace Creation Module
# ============================================================================
# Purpose: Creates Databricks workspace with customer-managed VPC (Premium tier)
# Provider: databricks.mws (account-level operations)
# Dependencies: storage_config, credentials, network_config, metastore (optional)
#
# This is Step 16 - the final infrastructure component that creates the
# Databricks E2 (Enterprise) workspace on AWS Premium tier.
#
# DEPLOYMENT MODEL:
# - Customer-Managed VPC: Full control over networking, security groups, route tables
# - Multi-AZ High Availability: Spans multiple availability zones
# - Unity Catalog Enabled: Modern data governance with metastore
# - Premium Tier: RBAC, audit logs, compliance features
#
# WORKSPACE NAMING:
# - workspace_name: User-facing display name (can contain spaces, special chars)
# - deployment_name: Infrastructure deployment name (lowercase, alphanumeric, unique globally)
#   Format: <project>-<env>-<region> (e.g., "dbx-tf-dev-us-east-2")
#
# SECURITY CONSIDERATIONS:
# - Network isolation via customer-managed VPC
# - IAM role with least-privilege permissions
# - S3 bucket encryption (SSE-S3 default, KMS optional)
# - External ID prevents confused deputy attacks
# - Security groups restrict traffic (SGs + NACLs defense-in-depth)
#
# COST FACTORS:
# - Workspace metadata: ~$0 (Databricks pays for control plane storage)
# - Compute: Per DBU consumed (Jobs, Interactive, SQL, DLT tiers)
# - Storage: Your S3 costs (typically $0.023/GB/month standard)
# - Network: NAT Gateway ($0.045/hour + $0.045/GB transfer)
# - VPC Endpoints: $0.01/hour per endpoint (~$7/month for S3 + STS)
#
# BEST PRACTICES:
# 1. One workspace per team/department for isolation and chargeback
# 2. Use deployment_name format: <project>-<env>-<region>
# 3. Enable Unity Catalog for data governance
# 4. Assign metastore immediately (auto-assign or explicit)
# 5. Enable token usage tracking and workspace analytics
# 6. Use tags consistently for cost allocation
# ============================================================================

# ============================================================================
# Databricks Workspace Resource
# ============================================================================
# Creates E2 (Enterprise) workspace on AWS with customer-managed VPC.
# This is the culmination of all previous infrastructure setup:
# - VPC, subnets, security groups (networking modules)
# - S3 root bucket (databricks_s3_root_bucket module)
# - IAM role with storage + compute policies (databricks_iam_* modules)
# - Storage configuration (databricks_storage_config module)
# - Network configuration (databricks_network_config module)
# - Unity Catalog metastore (databricks_metastore module)
#
# WORKSPACE LIFECYCLE:
# 1. Databricks creates control plane in its AWS account
# 2. Cross-account IAM role allows Databricks to provision compute in YOUR VPC
# 3. Classic compute plane launches EC2 instances in your private subnets
# 4. Data stored in YOUR S3 buckets (you pay, you control)
# 5. Workspace URL: https://<deployment_name>.cloud.databricks.com
#
# DELETION BEHAVIOR:
# - Workspace deletion does NOT delete VPC, S3 buckets, or IAM roles
# - These are separate resources that can be reused
# - Network config and storage config can be reused for new workspaces
# ============================================================================
resource "databricks_mws_workspaces" "workspace" {
  provider = databricks.mws

  # Account and region configuration
  account_id = var.dbx_account_id
  aws_region = var.aws_region

  # Workspace naming
  workspace_name  = var.workspace_name  # User-facing display name
  deployment_name = var.deployment_name # Globally unique infrastructure identifier (format: <project>-<env>-<region>)

  # Infrastructure dependencies - IDs from previous modules
  credentials_id           = var.credentials_id           # From databricks_storage_config module (mws_credentials)
  storage_configuration_id = var.storage_configuration_id # From databricks_storage_config module (mws_storage_configurations)
  network_id               = var.network_id               # From databricks_network_config module (mws_networks)

  # Pricing tier - Premium for RBAC, Unity Catalog, audit logs
  # Options: STANDARD (basic features), PREMIUM (RBAC, audit), ENTERPRISE (reserved capacity)
  # Premium tier required for: Unity Catalog, IP Access Lists, Private Link, SCIM provisioning
  pricing_tier = var.pricing_tier

  # Lifecycle management
  # Allow Terraform to manage workspace updates and recreations
  lifecycle {
    # Ignore changes to token_info (workspace generates tokens dynamically)
    ignore_changes = [
      # Workspace tokens are managed separately via Databricks UI or API
    ]
  }

  # Dependency management
  # Ensure all prerequisite resources are created first
  depends_on = [
    # Implicit: credentials_id, storage_configuration_id, network_id must exist
    # These are enforced by variable requirements
  ]

  # Resource tagging for cost allocation and organization
  # Tags inherited from root module (project_name, env, region, etc.)
  # Additional workspace-specific tags can be added
}

# ============================================================================
# Metastore Assignment (Optional but Recommended)
# ============================================================================
# Assigns Unity Catalog metastore to workspace.
# Without this, workspace operates in legacy Hive metastore mode (deprecated).
#
# ASSIGNMENT OPTIONS:
# 1. Automatic: If metastore has default_data_access_config_id set and
#    workspaces in same region auto-assign to regional metastore
# 2. Explicit: Use this resource to assign specific metastore
#
# BEST PRACTICE:
# - Create metastore BEFORE workspace (completed in Step 15)
# - Assign metastore IMMEDIATELY after workspace creation
# - One metastore per region, shared across multiple workspaces
# - Cannot change metastore after assignment (permanent decision)
#
# METASTORE ARCHITECTURE:
# - Metastore: Region-level object, shared across workspaces
# - Catalog: Namespace for databases (three-level: catalog.schema.table)
# - Each catalog should have MANAGED LOCATION 's3://bucket/catalog-name/'
# - Managed tables automatically inherit catalog's storage location
# - External tables can reference data anywhere (but lose optimization features)
# ============================================================================
# NOTE: Metastore assignment is ALWAYS done because the metastore is created
# before the workspace in the root module. No conditional count needed.
resource "databricks_metastore_assignment" "workspace_metastore" {
  provider = databricks.mws

  workspace_id = databricks_mws_workspaces.workspace.workspace_id
  metastore_id = var.metastore_id

  # Lifecycle management
  lifecycle {
    # Prevent accidental metastore reassignment
    prevent_destroy = true
  }

  depends_on = [
    databricks_mws_workspaces.workspace
  ]
}

# ============================================================================
# Workspace Outputs
# ============================================================================
# These outputs are used by workspace-level configurations and user documentation.
# ============================================================================
output "workspace_id" {
  description = "Numeric workspace ID (used for API calls and metastore assignment)"
  value       = databricks_mws_workspaces.workspace.workspace_id
}

output "workspace_url" {
  description = "Workspace URL (https://<deployment_name>.cloud.databricks.com)"
  value       = databricks_mws_workspaces.workspace.workspace_url
}

output "workspace_name" {
  description = "User-facing workspace display name"
  value       = databricks_mws_workspaces.workspace.workspace_name
}

output "deployment_name" {
  description = "Infrastructure deployment name (globally unique identifier)"
  value       = databricks_mws_workspaces.workspace.deployment_name
}

output "workspace_status" {
  description = "Workspace provisioning status (RUNNING, PROVISIONING, FAILED)"
  value       = databricks_mws_workspaces.workspace.workspace_status
}

output "workspace_status_message" {
  description = "Human-readable status message with additional context"
  value       = databricks_mws_workspaces.workspace.workspace_status_message
}

output "pricing_tier" {
  description = "Workspace pricing tier (PREMIUM for Unity Catalog and RBAC)"
  value       = databricks_mws_workspaces.workspace.pricing_tier
}

output "aws_region" {
  description = "AWS region where workspace is deployed"
  value       = databricks_mws_workspaces.workspace.aws_region
}

output "metastore_id" {
  description = "ID of assigned Unity Catalog metastore"
  value       = var.metastore_id
}

# ============================================================================
# Usage Instructions Output
# ============================================================================
output "next_steps" {
  description = "Post-deployment instructions for workspace configuration"
  value       = <<-EOT
    ================================================================================
    DATABRICKS WORKSPACE CREATED SUCCESSFULLY
    ================================================================================

    Workspace URL: ${databricks_mws_workspaces.workspace.workspace_url}
    Workspace ID: ${databricks_mws_workspaces.workspace.workspace_id}
    Deployment Name: ${coalesce(databricks_mws_workspaces.workspace.deployment_name, "auto-generated")}
    Region: ${databricks_mws_workspaces.workspace.aws_region}
    Pricing Tier: ${databricks_mws_workspaces.workspace.pricing_tier}
    Unity Catalog: ${var.metastore_id != null ? "ENABLED (Metastore: ${var.metastore_id})" : "NOT ASSIGNED"}

    ================================================================================
    NEXT STEPS - WORKSPACE CONFIGURATION
    ================================================================================

    1. LOGIN TO WORKSPACE:
       - Navigate to: ${databricks_mws_workspaces.workspace.workspace_url}
       - Use account admin credentials (SSO or username/password)
       - First login may take 2-3 minutes for workspace initialization

    2. VERIFY UNITY CATALOG (if assigned):
       - SQL Editor → Catalogs → Verify metastore appears
       - Create catalog: CREATE CATALOG <name> MANAGED LOCATION 's3://bucket/catalog/'
       - Grant permissions: GRANT USE CATALOG ON <catalog> TO <principal>

    3. CREATE COMPUTE RESOURCES:
       - Compute → Create cluster (or SQL Warehouse for analytics)
       - Use Single User or Shared mode (Shared requires Premium)
       - Enable autoscaling: Min 1, Max 8 workers (adjust for workload)
       - Use latest LTS runtime (14.3 LTS as of Oct 2024)

    4. CONFIGURE WORKSPACE SETTINGS:
       - Admin Console → Workspace Settings
       - Enable: Audit Logs, Token Tracking, Workspace Analytics
       - Set: Default cluster policies, instance profiles, init scripts
       - Configure: IP Access Lists (if needed), Private Link (if enabled)

    5. USER MANAGEMENT (SCIM RECOMMENDED):
       - Manual: Admin Console → Users → Add users/service principals
       - SCIM: Configure Azure AD / Okta / OneLogin integration
       - Groups: Create groups for RBAC (analysts, engineers, admins)

    6. DATA ACCESS CONFIGURATION:
       - Unity Catalog: Grants managed via SQL (GRANT SELECT ON...)
       - Legacy: Instance profiles for S3 access (not recommended)
       - Secrets: Use Databricks Secrets (scope + key) for credentials

    7. COST MANAGEMENT:
       - Billing → Usage Dashboard (monitor DBU consumption)
       - Set budget alerts in AWS Cost Explorer
       - Use cluster policies to limit instance types
       - Enable auto-termination (15-30 minutes idle)

    8. BACKUP AND DISASTER RECOVERY:
       - Export notebooks regularly (Repos integration with Git)
       - Document workspace configuration (Terraform state)
       - Metastore metadata backed up automatically by Databricks
       - S3 data: Enable versioning + cross-region replication

    ================================================================================
    RECOMMENDED INITIAL CATALOG SETUP (Unity Catalog)
    ================================================================================

    -- Create main catalog with managed location
    CREATE CATALOG main
    MANAGED LOCATION 's3://your-bucket/catalogs/main/';

    -- Create development catalog
    CREATE CATALOG dev
    MANAGED LOCATION 's3://your-bucket/catalogs/dev/';

    -- Create analytics catalog for BI tools
    CREATE CATALOG analytics
    MANAGED LOCATION 's3://your-bucket/catalogs/analytics/';

    -- Grant usage to all users on main catalog
    GRANT USE CATALOG ON main TO `account users`;
    GRANT USE SCHEMA ON ALL SCHEMAS IN CATALOG main TO `account users`;

    -- Create schema for raw data
    CREATE SCHEMA main.bronze;
    CREATE SCHEMA main.silver;
    CREATE SCHEMA main.gold;

    ================================================================================
    TROUBLESHOOTING
    ================================================================================

    IF WORKSPACE NOT ACCESSIBLE:
    - Check workspace_status output (should be "RUNNING")
    - Verify network configuration allows egress to Databricks control plane
    - Check security groups allow required ports (443, 3306, 8443-8451)
    - Review IAM role trust policy has correct External ID

    IF UNITY CATALOG NOT VISIBLE:
    - Verify metastore assigned to workspace (check metastore_assigned output)
    - Ensure user has account admin or metastore admin role
    - Check data access configuration has correct IAM role ARN
    - Verify IAM role has S3 permissions to metastore storage

    IF CLUSTERS WON'T START:
    - Check cross-account IAM policy has all 52 EC2 actions
    - Verify subnets have available IP addresses (/26 minimum, 64 IPs)
    - Check NAT Gateway is functional (private subnets need internet egress)
    - Review VPC endpoints for S3/STS are configured correctly

    DOCUMENTATION:
    - Architecture: ARCHITECTURE.md
    - Cross-Account Setup: CROSS_ACCOUNT_SETUP.md
    - Deployment Steps: DEPLOYMENT_STEPS.md
    - Databricks Docs: https://docs.databricks.com/

    ================================================================================
  EOT
}
