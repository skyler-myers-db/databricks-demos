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
# 0. terraform_backend   → Creates S3 + DynamoDB for remote state (optional, run first)
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
# ✅ Remote state ready (S3 + DynamoDB for team collaboration)
#
# ============================================================================

# ============================================================================
# STEP 0: TERRAFORM BACKEND INFRASTRUCTURE
# ============================================================================
# Purpose: Create S3 bucket + DynamoDB table for remote Terraform state
#
# DEPLOYMENT WORKFLOW:
# 1. First apply: Creates backend resources (using local state)
# 2. After successful apply: Copy backend config from output
# 3. Add backend config to versions.tf
# 4. Run: terraform init -migrate-state
# 5. Subsequent applies: Use remote state in S3 (team collaboration ready)
#
# No chicken-and-egg problem: Backend resources are created WITH the
# infrastructure in first apply, then state is migrated to S3 afterward.
# ============================================================================
module "terraform_backend" {
  source = "./modules/terraform_backend"

  providers = {
    aws = aws.dev
  }

  project_name = var.project_name
  env          = var.env
}

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
  flow_logs_retention_days = 30 # Compliance requirement: 30 days minimum for SOC2/HIPAA

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

# Step 10a: Create KMS key for S3 encryption (Compliance requirement)
module "kms" {
  source = "./modules/aws_kms"

  providers = {
    aws = aws.dev
  }

  project_name        = var.project_name
  env                 = var.env
  databricks_role_arn = module.databricks_iam_role.role_arn

  depends_on = [module.databricks_iam_role]
}

# Step 10b: Create S3 root bucket for Databricks workspace storage (DBFS root)
module "databricks_s3_root" {
  source = "./modules/databricks_s3_root_bucket"

  providers = {
    aws = aws.dev
  }

  project_name       = var.project_name
  env                = var.env
  workspace_name     = "${var.project_name}-${var.env}-workspace"
  dbx_account_id     = var.dbx_account_id
  log_retention_days = 365                    # Cluster logs retention (1 year)
  kms_key_arn        = module.kms.kms_key_arn # Customer-managed KMS encryption

  # Bucket naming: databricks-workspace-<project>-<env>
  # Example: databricks-workspace-myproject-dev

  depends_on = [module.kms]
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

  # KMS encryption enabled for compliance
  kms_key_arn = module.kms.kms_key_arn

  # File events management (highly recommended by Databricks)
  enable_file_events = true

  # Comprehensive permissions per Databricks Step 3:
  # Policy 1 (Unity Catalog): S3 (/unity-catalog/* paths), KMS (if enabled), STS (self-assuming)
  # Policy 2 (File Events): S3 notifications, SNS topic mgmt, SQS queue mgmt
}

# Step 12b: Attach cross-account compute policy to Databricks IAM role (Step 2 - Workspace credentials)
module "databricks_cross_account_policy" {
  source = "./modules/databricks_cross_account_policy"

  providers = {
    aws = aws.dev
  }

  # Dependency: Wait for IAM role to be created
  depends_on = [module.databricks_iam_role]

  policy_name    = "${var.project_name}-${var.env}-databricks-cross-account"
  role_name      = module.databricks_iam_role.role_name
  workspace_name = "${var.project_name}-${var.env}-workspace"
  project_name   = var.project_name
  env            = var.env

  # Grants comprehensive EC2 and IAM permissions per Databricks Step 2:
  # - EC2: Launch/terminate instances, volumes, security groups, spot/fleet management
  # - IAM: Create service-linked role for EC2 Spot
  # Deployment type: Customer-managed VPC with default restrictions
}

# Step 13: Create Databricks storage configuration (Step 4 - Databricks account config)
module "databricks_storage_config" {
  source = "./modules/databricks_storage_config"

  providers = {
    databricks = databricks.mws
  }

  # Explicit dependencies: Wait for all AWS resources to be ready AND IAM to propagate
  # Dependencies: Ensure all prerequisites are met before creating storage config
  depends_on = [
    module.databricks_s3_root,
    module.databricks_iam_role,
    module.databricks_iam_policy,
    module.databricks_cross_account_policy
  ]

  # Configuration naming
  storage_configuration_name = "${var.project_name}-${var.env}-storage-config"
  credentials_name           = "${var.project_name}-${var.env}-credentials"

  # AWS resources to register with Databricks account
  databricks_account_id = var.dbx_account_id
  bucket_name           = module.databricks_s3_root.bucket_name
  role_arn              = module.databricks_iam_role.role_arn

  # Metadata
  project_name = var.project_name
  env          = var.env

  # This creates account-level storage configuration that references:
  # - S3 bucket (from Step 1)
  # - IAM role ARN (from Step 2)
  # - IAM policies are already attached (from Step 3)
  # Storage configuration ID will be used in Step 6 (workspace creation)
}

# Step 14: Create Databricks network configuration (Step 5 - Customer-managed VPC)
module "databricks_network_config" {
  source = "./modules/databricks_network_config"

  providers = {
    databricks = databricks.mws
  }

  # Explicit dependencies: Wait for all networking resources to be ready
  depends_on = [
    module.vpc,
    module.subnets,
    module.security_groups,
    module.route_tables,
    module.network_acls,
    module.vpc_endpoints
  ]

  # Configuration naming
  network_configuration_name = "${var.project_name}-${var.env}-network-config"

  # AWS networking resources to register with Databricks account
  databricks_account_id = var.dbx_account_id
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.subnets.private_subnet_ids
  security_group_ids    = [module.security_groups.databricks_workspace_security_group_id]

  # Metadata
  project_name = var.project_name
  env          = var.env

  # This creates account-level network configuration that references:
  # - VPC with flow logs and DNS enabled
  # - Private subnets (minimum 2 in different AZs)
  # - Databricks workspace security group with all required rules
  # IMPORTANT: Network config CANNOT be reused across workspaces (per Databricks docs)
  # Network configuration ID will be used in Step 6 (workspace creation)
}

# Step 15: Create Unity Catalog metastore (BEFORE workspace creation)
module "databricks_metastore" {
  source = "./modules/databricks_metastore"

  providers = {
    databricks = databricks.mws
  }

  # Explicit dependencies: Wait for IAM role to be ready
  depends_on = [
    module.databricks_iam_role,
    module.databricks_cross_account_policy
  ]

  # Metastore configuration
  metastore_name          = "${var.project_name}-${var.env}-${var.aws_region}-metastore"
  aws_region              = var.aws_region
  metastore_owner         = var.dbx_metastore_owner_email
  data_access_config_name = "${var.project_name}-${var.env}-data-access"
  iam_role_arn            = module.databricks_iam_role.role_arn

  # Metadata
  project_name = var.project_name
  env          = var.env

  # Modern best practice: NO storage_root
  # - Metastore has no default storage location
  # - Each catalog must specify MANAGED LOCATION 's3://your-bucket/catalog-name/'
  # - Promotes catalog-level governance and organization
  # - Enables full managed table features (predictive optimization, liquid clustering)
  # Metastore metadata (catalogs, schemas, permissions) stored in Databricks control plane ($0 cost)
}

# ============================================================================
# STEP 16: DATABRICKS WORKSPACE CREATION
# ============================================================================
# Purpose: Create Databricks E2 workspace on AWS Premium tier
# Module: databricks_workspace
# Provider: databricks.mws (account-level)
#
# THIS IS THE FINAL STEP that brings all infrastructure together:
# - VPC, subnets, security groups (Steps 6-14)
# - S3 root bucket (Step 1)
# - IAM role with storage + compute policies (Steps 2-3)
# - Storage configuration (Step 4)
# - Network configuration (Step 5)
# - Unity Catalog metastore (Step 15)
#
# WORKSPACE ARCHITECTURE:
# - Control Plane: Databricks-managed AWS account (web UI, notebooks, metadata)
# - Classic Compute Plane: YOUR AWS account VPC (EC2 clusters, data processing)
# - Storage: YOUR S3 buckets (you pay, you control, you encrypt)
# - Unity Catalog: Shared metastore across workspaces (one per region)
#
# NAMING CONVENTIONS:
# - workspace_name: User-facing display (e.g., "Databricks Analytics Dev")
# - deployment_name: Infrastructure ID (e.g., "dbx-tf-dev-us-east-2")
#   Must be globally unique across ALL Databricks customers
#   Format: <project>-<env>-<region> (lowercase, alphanumeric, hyphens)
#
# WORKSPACE URL:
# - Format: https://<deployment_name>.cloud.databricks.com
# - Example: https://dbx-tf-dev-us-east-2.cloud.databricks.com
#
# PRICING TIER:
# - PREMIUM: Required for Unity Catalog, RBAC, IP Access Lists, Private Link
# - Includes: Audit logs, compliance features, advanced security
# - Cost: Charged per DBU consumed (compute usage)
#
# UNITY CATALOG ASSIGNMENT:
# - Metastore assigned immediately after workspace creation
# - Cannot change metastore after assignment (permanent decision)
# - One metastore per region, shared across multiple workspaces
# - Each workspace can have multiple catalogs within the metastore
#
# DEPLOYMENT TIME:
# - Workspace provisioning: 5-10 minutes
# - First login initialization: 2-3 minutes
# - Cluster creation: 3-5 minutes
# - Total time to first query: ~15 minutes
#
# COST FACTORS (Monthly Estimates):
# - Workspace metadata: $0 (Databricks pays control plane costs)
# - NAT Gateway: ~$40-50/month ($0.045/hour + $0.045/GB transfer)
# - VPC Endpoints: ~$14/month (2 endpoints × $0.01/hour × 730 hours)
# - S3 Storage: ~$0.023/GB/month standard storage
# - Compute: Variable based on DBU consumption (Jobs, Interactive, SQL, DLT)
# - Example: 100 hours/month @ 2 DBUs/hour = $0.40/DBU × 2 × 100 = $80/month
# ============================================================================
module "databricks_workspace" {
  source = "./modules/databricks_workspace"

  providers = {
    databricks.mws = databricks.mws
  }

  # Explicit dependencies: All infrastructure must exist first
  depends_on = [
    module.databricks_storage_config, # Step 4: Storage + credentials
    module.databricks_network_config, # Step 5: VPC registration
    module.databricks_metastore       # Step 15: Unity Catalog metastore
  ]

  # Account configuration
  dbx_account_id = var.dbx_account_id
  aws_region     = var.aws_region

  # Workspace naming
  workspace_name  = "${var.project_name} Analytics ${title(replace(var.env, "-", ""))}" # "Databricks TF Analytics Dev"
  deployment_name = "${var.project_name}${var.env}-${var.aws_region}"                   # "dbx-tf-dev-us-east-2"

  # Infrastructure dependencies (IDs from previous modules)
  credentials_id           = module.databricks_storage_config.credentials_id
  storage_configuration_id = module.databricks_storage_config.storage_configuration_id
  network_id               = module.databricks_network_config.network_id

  # Pricing tier (PREMIUM for Unity Catalog and RBAC)
  pricing_tier = "PREMIUM"

  # Unity Catalog metastore assignment
  metastore_id         = module.databricks_metastore.metastore_id
  default_catalog_name = "main" # Default catalog for workspace queries

  # Metadata for tagging and naming
  project_name = var.project_name
  env          = var.env
}

# ============================================================================
# STEP 17: USER PROVISIONING - Service Principal & Workspace Permissions
# ============================================================================
# Purpose: Set up automation service principal and assign workspace admins
#
# STRATEGY WITH GOOGLE SCIM:
# ---------------------------
# - Users/Groups: Managed by Google SCIM (source of truth)
# - Service Principals: Managed by Terraform (automation accounts)
# - Workspace Assignments: Managed by Terraform (who has access)
#
# WHY THIS APPROACH:
# ------------------
# With SCIM enabled, you should NEVER manage users/groups in Terraform.
# Google is your IdP and source of truth. Terraform would conflict with SCIM.
#
# Instead, Terraform:
# 1. Creates service principals (automation accounts, not synced via SCIM)
# 2. References existing SCIM-synced users/groups via data sources
# 3. Assigns those users/groups to workspaces
#
# USER MANAGEMENT WORKFLOW:
# -------------------------
# Adding new user to data_engineers group:
# 1. Add user to "data_engineers" group in Google Workspace
# 2. SCIM automatically syncs to Databricks
# 3. User automatically gets workspace access (no Terraform change needed!)
#
# ADMIN USER ASSIGNMENT:
# ----------------------
# Your user (skyler@entrada.ai) is assigned as workspace admin on every
# workspace via the workspace_permissions module. This happens automatically
# for all workspaces created with this pattern.
# ============================================================================

# Step 17a: Create Service Principal for Workspace Infrastructure Management
module "workspace_service_principal" {
  source = "./modules/databricks_service_principal"

  providers = {
    databricks.mws = databricks.mws
  }

  depends_on = [
    module.databricks_workspace
  ]

  # Service principal naming
  service_principal_name = "${var.project_name}-workspace-terraform${var.env}"

  # Workspace assignment
  workspace_id  = module.databricks_workspace.workspace_id
  workspace_url = module.databricks_workspace.workspace_url

  # Metadata
  project_name = var.project_name
  env          = var.env
}

# Step 17b: Assign Workspace Admins (SCIM-synced users and groups)
module "workspace_permissions" {
  source = "./modules/databricks_workspace_permissions"

  providers = {
    databricks.mws = databricks.mws
  }

  depends_on = [
    module.databricks_workspace
  ]

  # Workspace to assign permissions to
  workspace_id = module.databricks_workspace.workspace_id

  # Admin user (must exist via SCIM sync from Google)
  admin_user_email = var.workspace_admin_email

  # Data engineers group (must exist via SCIM sync from Google)
  data_engineers_group_name   = var.data_engineers_group_name
  assign_data_engineers_group = var.assign_data_engineers_group

  # Metadata
  project_name = var.project_name
  env          = var.env
}

resource "databricks_grants" "metastore_admins" {
  provider  = databricks.workspace_admin
  metastore = module.databricks_metastore.metastore_id

  grant {
    principal = module.workspace_service_principal.service_principal_id
    privileges = [
      "CREATE_CATALOG",
      "CREATE_EXTERNAL_LOCATION",
      "CREATE_STORAGE_CREDENTIAL"
    ]
  }

  depends_on = [
    module.workspace_service_principal,
    module.workspace_permissions,
    module.databricks_workspace
  ]
}

# ============================================================================
# STEP 17c: ACCOUNT ADMIN ASSIGNMENT
# ============================================================================
# Purpose: Assign admin user as account-level administrator
# Scope: Account-level (mws) - full account administration rights
#
# PERMISSIONS GRANTED:
# - Full account administration (create workspaces, metastores, etc.)
# - Manage account-level groups and service principals
# - Configure account settings and billing
# - View audit logs and usage metrics
#
# WHY NEEDED:
# - Provides human administrator access for account management
# - Separate from workspace admin (different scope)
# - Required for Unity Catalog administration
# ============================================================================
resource "databricks_mws_permission_assignment" "account_admin" {
  provider     = databricks.mws
  workspace_id = module.databricks_workspace.workspace_id
  principal_id = data.databricks_user.account_admin.id
  permissions  = ["ADMIN"]

  depends_on = [
    module.databricks_workspace
  ]
}

# Data source to lookup the admin user (synced from Google SCIM)
data "databricks_user" "account_admin" {
  provider  = databricks.mws
  user_name = var.workspace_admin_email
}

# ============================================================================
# STEP 17d: UNITY CATALOG STORAGE BUCKET
# ============================================================================
# Purpose: S3 bucket for Unity Catalog managed table storage
# Stores: Catalog data, managed tables, checkpoints, temporary files
#
# WHY NEEDED:
# - Unity Catalog requires S3 bucket for managed table storage
# - Separate from root bucket (root = workspace metadata, this = data)
# - Encrypted with customer-managed KMS key
# - Supports versioning and lifecycle policies
# ============================================================================
module "unity_catalog_storage" {
  source = "./modules/databricks_unity_catalog_bucket"

  providers = {
    aws = aws.dev
  }

  bucket_name           = "${var.project_name}-${var.env}-unity-catalog-storage"
  force_destroy         = var.force_destroy
  kms_key_arn           = module.kms.kms_key_arn
  databricks_account_id = var.dbx_account_id
  aws_account_id        = module.aws_account.account_id
  aws_tags              = var.aws_tags
  project_name          = var.project_name
  env                   = var.env

  depends_on = [
    module.kms,
    module.databricks_workspace
  ]
}

# ============================================================================
# STEP 17e: JOB RUNNER SERVICE PRINCIPAL
# ============================================================================
# Purpose: Service principal for running Databricks jobs via Asset Bundles
# Scope: Account-level, workspace USER permissions (NOT admin)
#
# USE CASES:
# - CI/CD pipelines deploying jobs via Databricks Asset Bundles
# - Scheduled job execution
# - Automated workflows
#
# PERMISSIONS:
# - CAN: Run jobs, read/write data (via catalog grants), create clusters
# - CANNOT: Manage users, create workspaces, modify account settings
# ============================================================================
module "job_runner_service_principal" {
  source = "./modules/databricks_job_runner_service_principal"

  providers = {
    databricks.mws = databricks.mws
  }

  service_principal_name = var.job_runner_sp_name
  workspace_id           = module.databricks_workspace.workspace_id
  workspace_url          = module.databricks_workspace.workspace_url
  project_name           = var.project_name
  env                    = var.env

  depends_on = [module.databricks_workspace]
}

# ============================================================================
# STEP 17f: UNITY CATALOG STORAGE CREDENTIAL & EXTERNAL LOCATION
# ============================================================================
# Purpose: Reusable storage credential for Unity Catalog data bucket
# Scope: ONE credential for the entire bucket (used by ALL catalogs)
#
# WHAT IT CREATES:
# - IAM Role: Self-assuming with full S3/KMS/SNS/SQS permissions
# - Storage Credential: Databricks object referencing IAM role
# - External Location: Points to BUCKET ROOT (s3://bucket/)
#
# REUSABILITY:
# - Storage credential can be used by multiple catalogs
# - External location at bucket root allows any catalog to use it
# - Each catalog gets its own subdirectory (datapact/, bronze/, silver/, etc.)
# ============================================================================
module "unity_catalog_storage_credential" {
  source = "./modules/databricks_unity_catalog_storage_credential"

  providers = {
    databricks.workspace = databricks.workspace
    aws                  = aws.dev
  }

  storage_credential_name = "${var.project_name}_${var.env}_unity_catalog_storage"
  storage_bucket_name     = module.unity_catalog_storage.bucket_name
  storage_bucket_arn      = module.unity_catalog_storage.bucket_arn
  databricks_account_id   = var.dbx_account_id
  aws_account_id          = module.aws_account.account_id
  aws_region              = var.aws_region
  assume_role_name        = var.aws_acc_switch_role
  kms_key_arn             = module.kms.kms_key_arn
  project_name            = var.project_name
  env                     = var.env

  depends_on = [
    module.unity_catalog_storage,
    module.databricks_metastore,
    module.kms,
    databricks_grants.metastore_admins
  ]
}

# ============================================================================
# STEP 17g: DATAPACT CATALOG
# ============================================================================
# Purpose: Unity Catalog for application data
# Storage: s3://bucket/datapact/ (subdirectory in Unity Catalog bucket)
#
# ARCHITECTURE:
# - Uses shared storage credential (created above)
# - Uses shared external location (bucket root)
# - Catalog's managed storage: s3://bucket/datapact/
# - Tables created without LOCATION use this path automatically
#
# EXAMPLE:
#   CREATE TABLE datapact.default.users (id INT, name STRING);
#   -- Data stored at: s3://bucket/datapact/default/users/
# ============================================================================
module "datapact_catalog" {
  source = "./modules/databricks_unity_catalog"

  providers = {
    databricks.workspace = databricks.workspace
  }

  catalog_name     = var.catalog_name
  metastore_id     = module.databricks_metastore.metastore_id
  storage_root_url = format("%s/%s", trimsuffix(module.unity_catalog_storage_credential.external_location_url, "/"), var.catalog_name)
  project_name     = var.project_name
  env              = var.env
  assume_role_name = var.aws_acc_switch_role

  depends_on = [
    module.unity_catalog_storage_credential
  ]
}

# ============================================================================
# STEP 17h: CLUSTER POLICIES - Compute Governance
# ============================================================================
# Purpose: Define cluster policies for different user personas
# Policies: data_engineering, analyst, admin
#
# SANDBOX ENVIRONMENT STRATEGY:
# - Broad permissions for experimentation
# - Cost guardrails (auto-termination, autoscaling limits)
# - Spot instances for cost savings (~70% reduction)
# - Intelligent instance type restrictions
#
# COST CONTROLS:
# - Auto-termination: 30-120 minutes idle (prevents forgotten clusters)
# - Autoscaling: Max 20 workers for data engineering, 8 for analysts
# - Spot instances with ON_DEMAND fallback (high availability)
# - Photon engine default (3-5x faster queries, lower costs)
# ============================================================================
module "cluster_policies" {
  source = "./modules/databricks_cluster_policies"

  providers = {
    databricks = databricks.workspace
  }

  workspace_name                = "${var.project_name}-${var.env}-workspace"
  env                           = var.env
  cost_center                   = var.cost_center
  allowed_instance_types        = var.cluster_policy_allowed_instance_types
  default_instance_type         = var.cluster_policy_default_instance_type
  analyst_instance_types        = var.cluster_policy_analyst_instance_types
  analyst_default_instance_type = var.cluster_policy_analyst_default_instance_type

  depends_on = [
    module.databricks_workspace
  ]
}

# ============================================================================
# STEP 17i: CATALOG GRANTS - Unity Catalog Permissions
# ============================================================================
# Purpose: Grant permissions on datapact catalog to users and service principals
# Principals:
# - skyler@entrada.ai: ALL PRIVILEGES (owner)
# - job-runner SP: ALL PRIVILEGES (for automation/DABs)
# - data_engineers group: Broad CRUD permissions (sandbox)
#
# SANDBOX PERMISSIONS:
# - CREATE SCHEMA, CREATE TABLE (experimentation)
# - SELECT, MODIFY (read/write data)
# - USE CATALOG, USE SCHEMA (access control)
# - CREATE FUNCTION, CREATE VOLUME, EXECUTE
#
# SECURITY NOTE:
# - Permissions at catalog + schema level
# - data_engineers group synced from Google Workspace via SCIM
# - Service principal for CI/CD automation
# ============================================================================
module "catalog_grants" {
  source = "./modules/databricks_catalog_grants"

  providers = {
    databricks = databricks.workspace
  }

  catalog_name                 = var.catalog_name
  catalog_owner_principal      = var.catalog_owner_email
  job_runner_sp_application_id = module.job_runner_service_principal.service_principal_application_id
  data_engineers_group_name    = var.data_engineers_group_name

  depends_on = [
    module.datapact_catalog,
    module.job_runner_service_principal,
    module.workspace_permissions
  ]
}

# ============================================================================
# STEP 18: AWS BUDGET ALERTS - Cost Management
# ============================================================================
# Purpose: Monitor AWS spending and send alerts at defined thresholds
# Cost: FREE (first 2 budgets included)
#
# WHAT IT PROVIDES:
# - Email alerts at 50%, 80%, 100%, 120% of monthly budget
# - Forecasted spending alerts (predictive)
# - Filtered by project and environment tags
# - Helps prevent bill shock
#
# ALERT RECIPIENTS:
# - All emails in var.budget_alert_emails variable
# - AWS will send confirmation emails (must click to subscribe)
# - Alerts sent once per day maximum per threshold
# ============================================================================
module "aws_budgets" {
  source = "./modules/aws_budgets"

  providers = {
    aws = aws.dev
  }

  project_name         = var.project_name
  env                  = var.env
  monthly_budget_limit = var.monthly_budget_limit
  dbu_budget_limit     = var.dbu_budget_limit
  create_dbu_budget    = var.create_dbu_budget
  alert_emails         = length(var.budget_alert_emails) > 0 ? var.budget_alert_emails : [var.admin_email]
  budget_start_date    = var.budget_start_date
}

# ============================================================================
# STEP 18: AWS CONFIG - Compliance & Configuration Monitoring
# ============================================================================
# Purpose: Continuously monitor AWS resource configurations for compliance
# Cost: ~$2-5/month (Config recorder + rules evaluation)
#
# WHAT IT PROVIDES:
# - 8 compliance rules (encrypted volumes, S3 security, MFA, etc.)
# - Configuration history stored in S3 (365-day retention)
# - Email alerts for compliance violations
# - Audit trail for SOC 2, HIPAA, PCI-DSS compliance
#
# COMPLIANCE RULES ENABLED:
# - encrypted-volumes: All EBS volumes must be encrypted
# - s3-bucket-public-read-prohibited: No public read access on S3
# - s3-bucket-public-write-prohibited: No public write access on S3
# - s3-bucket-ssl-requests-only: S3 must require HTTPS
# - s3-bucket-server-side-encryption-enabled: S3 encryption required
# - root-account-mfa-enabled: Root account must have MFA
# - vpc-flow-logs-enabled: VPC Flow Logs must be enabled
# - iam-password-policy: Strong password policy required
# ============================================================================
module "aws_config" {
  source = "./modules/aws_config"

  providers = {
    aws = aws.dev
  }

  project_name          = var.project_name
  env                   = var.env
  notification_email    = var.admin_email
  config_retention_days = 365 # 1 year retention for compliance audits
}

# ============================================================================
# STEP 19: AWS GUARDDUTY - Threat Detection & Security Monitoring
# ============================================================================
# Purpose: Continuously monitor for malicious activity and unauthorized behavior
# Cost: ~$5-10/month (based on data volume analyzed)
#
# WHAT IT DETECTS:
# - Compromised EC2 instances (crypto mining, C&C communication)
# - Compromised IAM credentials (leaked keys, privilege escalation)
# - S3 bucket attacks (data exfiltration, unusual access patterns)
# - Network attacks (port scanning, DDoS, unusual protocols)
# - Malware activity (known malicious IPs, domains, file hashes)
#
# DATA SOURCES ANALYZED:
# - VPC Flow Logs (network traffic patterns)
# - CloudTrail logs (API call patterns)
# - DNS logs (suspicious domain resolutions)
# - S3 data events (unusual bucket access)
# - Kubernetes audit logs (EKS API activity)
# - Malware protection (EBS volume scans)
#
# ALERT CONFIGURATION:
# - Email alerts for HIGH (7.0-8.9) and CRITICAL (9.0-10.0) severity findings
# - Alerts sent via SNS within 15 minutes of detection
# - Low severity findings auto-archived to reduce noise
# ============================================================================
module "aws_guardduty" {
  source = "./modules/aws_guardduty"

  providers = {
    aws = aws.dev
  }

  project_name       = var.project_name
  env                = var.env
  notification_email = var.admin_email
}
