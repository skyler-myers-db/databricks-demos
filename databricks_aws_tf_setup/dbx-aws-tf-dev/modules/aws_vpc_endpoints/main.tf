# ============================================================================
# AWS VPC Endpoints Module - Private AWS Service Connectivity
# ============================================================================
#
# PURPOSE:
# --------
# Creates VPC Endpoints for private connectivity to AWS services, eliminating
# the need for internet or NAT Gateway traffic. Critical for security, cost
# optimization, and Databricks operational requirements.
#
# VPC ENDPOINT TYPES:
# -------------------
# 1. GATEWAY ENDPOINTS (Free):
#    - S3: Delta Lake storage, notebooks, libraries, cluster logs
#    - DynamoDB: (Optional) For applications using DynamoDB
#
# 2. INTERFACE ENDPOINTS ($7.20/month each + $0.01/GB):
#    - STS: IAM role assumption, credential vending (REQUIRED)
#    - Kinesis Streams: Databricks control plane communication (REQUIRED)
#    - EC2: Cluster lifecycle management (RECOMMENDED)
#    - (Optional) Glue, Secrets Manager, CloudWatch, etc.
#
# WHY VPC ENDPOINTS ARE ESSENTIAL:
# ---------------------------------
# Security Benefits:
# - Traffic never traverses public internet
# - All communication stays within AWS network backbone
# - Meets strict compliance requirements (HIPAA, PCI-DSS, FedRAMP)
# - Reduces attack surface (no internet egress for AWS services)
#
# Cost Benefits:
# - S3 Gateway Endpoint: FREE (no charges)
# - Interface Endpoints: $0.01/GB vs $0.045/GB through NAT Gateway
# - Typical savings: 50-70% on AWS service data transfer costs
# - Example: 1TB/month through endpoints = $10 vs $45 through NAT
#
# Performance Benefits:
# - Lower latency (direct AWS backbone routing)
# - Higher throughput (no NAT Gateway bottleneck)
# - Better reliability (AWS managed service)
#
# DATABRICKS REQUIREMENTS (Premium Tier):
# ----------------------------------------
# REQUIRED Endpoints:
# 1. S3 (Gateway): Delta Lake, notebooks, cluster logs, libraries
# 2. STS (Interface): IAM role assumption for cluster auth
# 3. Kinesis (Interface): Internal Databricks control plane communication
#
# RECOMMENDED Endpoints:
# 4. EC2 (Interface): Reduces NAT traffic for cluster management
#
# OPTIONAL Endpoints (add if used):
# - Glue: If using EXTERNAL Hive metastore (NOT needed for Unity Catalog)
# - Secrets Manager: For secure credential storage
# - CloudWatch Logs: For logging infrastructure
# - KMS: For encryption key management
# - Systems Manager: For parameter store access
#
# NOTE: Unity Catalog has its own managed metastore and does NOT require AWS Glue.
# Only enable Glue endpoint if using legacy external Hive metastore integration.
#
# GATEWAY vs INTERFACE ENDPOINTS:
# --------------------------------
# Gateway Endpoints (S3, DynamoDB):
# - Free of charge
# - Routes added automatically to route tables
# - Supports endpoint policies for access control
# - Regional service (survives AZ failures)
# - Ideal for high-volume AWS services
#
# Interface Endpoints (STS, Kinesis, EC2, etc.):
# - $7.20/month per endpoint + $0.01/GB data transfer
# - ENIs placed in subnets (multi-AZ for HA)
# - Requires security groups for access control
# - Private DNS enabled (resolves AWS service DNS to private IPs)
# - Necessary for services without gateway endpoint support
#
# HIGH AVAILABILITY DESIGN:
# --------------------------
# - Gateway endpoints: Regional (inherently HA)
# - Interface endpoints: ENIs in multiple AZs (HA across AZs)
# - Private DNS: Automatically resolves to healthy endpoint
# - No single point of failure in endpoint architecture
#
# COST ANALYSIS (2 AZ deployment):
# ---------------------------------
# Gateway Endpoints:
# - S3: FREE
#
# Interface Endpoints (per endpoint):
# - Hourly: $0.01/hour × 24 × 30 = $7.20/month
# - Data: $0.01/GB processed
# - Multi-AZ: Charges per AZ (2 AZs = 2x hourly cost)
#
# Total Monthly Cost (typical Databricks setup):
# - S3 Gateway: $0
# - STS Interface: $14.40 (2 AZs)
# - Kinesis Interface: $14.40 (2 AZs)
# - EC2 Interface: $14.40 (2 AZs)
# - Base Total: ~$43/month + data transfer
#
# Savings vs NAT Gateway only:
# - 500GB AWS service traffic/month
# - Through NAT: $22.50 ($0.045/GB)
# - Through Endpoints: $5.00 ($0.01/GB)
# - Net Savings: ~$17.50/month (breakeven after ~2.5 months)
#
# ENTERPRISE TIER WITH PRIVATELINK:
# ----------------------------------
# With Databricks Enterprise + AWS PrivateLink:
# - All endpoints from Premium tier: Still required (no changes)
# - Additional: Databricks PrivateLink endpoint (control plane)
# - Cost: Similar to interface endpoint (~$14.40/month for 2 AZs)
# - Benefit: Eliminates NAT Gateway entirely (can save ~$64/month base)
# - Result: Total cost similar, but ZERO internet exposure
#
# PRIVATE DNS EXPLAINED:
# ----------------------
# When enabled (recommended):
# - AWS service DNS names (sts.amazonaws.com) resolve to private IPs
# - No code changes needed in applications
# - Automatic failover to healthy endpoint ENIs
# - Works seamlessly with AWS SDKs and CLIs
#
# When disabled:
# - Must use endpoint-specific DNS names
# - Requires code changes or DNS configuration
# - Less convenient, rarely used
#
# ENDPOINT POLICIES:
# ------------------
# VPC endpoint policies control:
# - Which AWS principals can access the endpoint
# - Which AWS resources can be accessed
# - What actions are allowed
# - Default: Full access (can be restricted for security)
#
# Example use cases for policies:
# - Restrict S3 access to specific buckets only
# - Limit STS role assumption to certain roles
# - Control which EC2 actions are permitted
# - Implement defense-in-depth security
#
# MODERN FEATURES (2024-2025):
# -----------------------------
# - Support for 100+ AWS services via interface endpoints
# - Enhanced monitoring with CloudWatch endpoint metrics
# - Cross-account endpoint sharing (AWS PrivateLink)
# - IPv6 support for interface endpoints
# - Improved DNS resolution with Route 53 Resolver
# - AWS-managed prefix lists for endpoint service ranges
#
# ============================================================================

# Get current region and account for endpoint service names
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ============================================================================
# S3 GATEWAY ENDPOINT (FREE - Always Enable This)
# ============================================================================
# Routes S3 API traffic privately through AWS backbone
# Critical for Delta Lake operations, cluster logs, notebooks, libraries

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.s3"
  vpc_endpoint_type = "Gateway"

  # Associate with private route tables (where Databricks clusters run)
  route_table_ids = var.private_route_table_ids

  # Optional: Add endpoint policy for additional security
  # policy = jsonencode({
  #   Version = "2012-10-17"
  #   Statement = [{
  #     Effect    = "Allow"
  #     Principal = "*"
  #     Action = [
  #       "s3:GetObject",
  #       "s3:PutObject",
  #       "s3:DeleteObject",
  #       "s3:ListBucket"
  #     ]
  #     Resource = [
  #       "arn:aws:s3:::dbfs-*/*",           # Databricks DBFS buckets
  #       "arn:aws:s3:::databricks-*/*",    # Databricks system buckets
  #       "arn:aws:s3:::your-data-bucket/*" # Your data buckets
  #     ]
  #   }]
  # })

  tags = {
    Name    = "vpce-s3-${var.project_name}-${var.env}"
    Type    = "gateway"
    Service = "s3"
    Cost    = "FREE"
    Tier    = "premium-required"
  }
}

# ============================================================================
# STS INTERFACE ENDPOINT (REQUIRED for Databricks)
# ============================================================================
# Used for IAM role assumption and credential vending
# Critical for Databricks instance profiles and secure credential management

resource "aws_vpc_endpoint" "sts" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = true # Resolves sts.amazonaws.com to private IPs

  # Modern feature: Specify DNS options
  dns_options {
    dns_record_ip_type = "ipv4" # Options: ipv4, dualstack, ipv6
  }

  tags = {
    Name    = "vpce-sts-${var.project_name}-${var.env}"
    Type    = "interface"
    Service = "sts"
    Cost    = "~$14.40/month (2 AZs) + data transfer"
    Tier    = "premium-required"
  }
}

# ============================================================================
# KINESIS STREAMS INTERFACE ENDPOINT (REQUIRED for Databricks)
# ============================================================================
# Used for internal Databricks control plane communication
# Required for workspace operations, cluster logs, and metrics

resource "aws_vpc_endpoint" "kinesis" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.kinesis-streams"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = true # Resolves kinesis.*.amazonaws.com to private IPs

  dns_options {
    dns_record_ip_type = "ipv4"
  }

  tags = {
    Name    = "vpce-kinesis-${var.project_name}-${var.env}"
    Type    = "interface"
    Service = "kinesis-streams"
    Cost    = "~$14.40/month (2 AZs) + data transfer"
    Tier    = "premium-required"
  }
}

# ============================================================================
# EC2 INTERFACE ENDPOINT (RECOMMENDED for production)
# ============================================================================
# Reduces NAT Gateway usage for cluster management operations
# Significant cost savings on EC2 API calls from Databricks control plane
# COST: $7.20/month per AZ ($14.40 for 2 AZs) + $0.01/GB
# Comment out this resource if you want to save ~$15/month

resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = true # Resolves ec2.*.amazonaws.com to private IPs

  dns_options {
    dns_record_ip_type = "ipv4"
  }

  tags = {
    Name    = "vpce-ec2-${var.project_name}-${var.env}"
    Type    = "interface"
    Service = "ec2"
    Cost    = "~$14.40/month (2 AZs) + data transfer"
    Tier    = "premium-recommended"
  }
}

# ============================================================================
# OPTIONAL: Additional Interface Endpoints
# ============================================================================
# Uncomment and configure as needed based on your Databricks usage
# Simply uncomment the resource block below - no boolean variables needed
# IMPORTANT: Each interface endpoint costs $7.20/month per AZ whether used or not

# ----------------------------------------------------------------------------
# AWS Glue Data Catalog (ONLY if using external Hive metastore)
# ----------------------------------------------------------------------------
# NOTE: Unity Catalog does NOT require this - it has its own managed metastore
# COST: $7.20/month per AZ ($14.40 for 2 AZs) + $0.01/GB
# Only enable if you have an existing external Hive metastore in AWS Glue
#
# resource "aws_vpc_endpoint" "glue" {
#   vpc_id              = var.vpc_id
#   service_name        = "com.amazonaws.${data.aws_region.current.id}.glue"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = var.private_subnet_ids
#   security_group_ids  = var.security_group_ids
#   private_dns_enabled = true
#
#   dns_options {
#     dns_record_ip_type = "ipv4"
#   }
#
#   tags = {
#     Name    = "vpce-glue-${var.project_name}-${var.env}"
#     Type    = "interface"
#     Service = "glue"
#     Cost    = "~$14.40/month (2 AZs) + data transfer"
#     Tier    = "optional-legacy-hive-only"
#     Note    = "NOT required for Unity Catalog - only for external Hive metastore"
#   }
# }

# ----------------------------------------------------------------------------
# AWS Secrets Manager (for secure credential storage)
# ----------------------------------------------------------------------------
# COST: $7.20/month per AZ ($14.40 for 2 AZs) + $0.01/GB
# Useful if storing database credentials, API keys, or other secrets
#
# resource "aws_vpc_endpoint" "secretsmanager" {
#   vpc_id              = var.vpc_id
#   service_name        = "com.amazonaws.${data.aws_region.current.id}.secretsmanager"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = var.private_subnet_ids
#   security_group_ids  = var.security_group_ids
#   private_dns_enabled = true
#
#   dns_options {
#     dns_record_ip_type = "ipv4"
#   }
#
#   tags = {
#     Name    = "vpce-secretsmanager-${var.project_name}-${var.env}"
#     Type    = "interface"
#     Service = "secretsmanager"
#     Cost    = "~$14.40/month (2 AZs) + data transfer"
#     Tier    = "optional"
#   }
# }

# ----------------------------------------------------------------------------
# AWS RDS (ONLY if using external Hive Metastore on RDS)
# ----------------------------------------------------------------------------
# NOTE: Unity Catalog does NOT require this - it has its own managed metastore
# COST: $7.20/month per AZ ($14.40 for 2 AZs) + $0.01/GB
# Only enable if you have an existing external Hive metastore on RDS
# Databricks requires MySQL/PostgreSQL/Aurora for external HMS
#
# resource "aws_vpc_endpoint" "rds" {
#   vpc_id              = var.vpc_id
#   service_name        = "com.amazonaws.${data.aws_region.current.id}.rds"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = var.private_subnet_ids
#   security_group_ids  = var.security_group_ids
#   private_dns_enabled = true
#
#   dns_options {
#     dns_record_ip_type = "ipv4"
#   }
#
#   tags = {
#     Name    = "vpce-rds-${var.project_name}-${var.env}"
#     Type    = "interface"
#     Service = "rds"
#     Cost    = "~$14.40/month (2 AZs) + data transfer"
#     Tier    = "optional-legacy-hive-only"
#     Note    = "NOT required for Unity Catalog - only for external RDS-based Hive metastore"
#   }
# }

# ----------------------------------------------------------------------------
# AWS KMS (for encryption key management)
# ----------------------------------------------------------------------------
# COST: $7.20/month per AZ ($14.40 for 2 AZs) + $0.01/GB
# Required if using customer-managed KMS keys for encryption
#
# resource "aws_vpc_endpoint" "kms" {
#   vpc_id              = var.vpc_id
#   service_name        = "com.amazonaws.${data.aws_region.current.id}.kms"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = var.private_subnet_ids
#   security_group_ids  = var.security_group_ids
#   private_dns_enabled = true
#
#   dns_options {
#     dns_record_ip_type = "ipv4"
#   }
#
#   tags = {
#     Name    = "vpce-kms-${var.project_name}-${var.env}"
#     Type    = "interface"
#     Service = "kms"
#     Cost    = "~$14.40/month (2 AZs) + data transfer"
#     Tier    = "optional"
#   }
# }

# ----------------------------------------------------------------------------
# CloudWatch Logs (for custom logging infrastructure)
# ----------------------------------------------------------------------------
# COST: $7.20/month per AZ ($14.40 for 2 AZs) + $0.01/GB
# Useful if sending logs directly to CloudWatch from clusters
#
# resource "aws_vpc_endpoint" "logs" {
#   vpc_id              = var.vpc_id
#   service_name        = "com.amazonaws.${data.aws_region.current.id}.logs"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = var.private_subnet_ids
#   security_group_ids  = var.security_group_ids
#   private_dns_enabled = true
#
#   dns_options {
#     dns_record_ip_type = "ipv4"
#   }
#
#   tags = {
#     Name    = "vpce-logs-${var.project_name}-${var.env}"
#     Type    = "interface"
#     Service = "logs"
#     Cost    = "~$14.40/month (2 AZs) + data transfer"
#     Tier    = "optional"
#   }
# }

# ============================================================================
# ENTERPRISE TIER: Databricks PrivateLink Endpoint
# ============================================================================
# Uncomment this section when upgrading to Databricks Enterprise tier
# Provides fully private connectivity to Databricks control plane
# Simply uncomment and provide the service_name from Databricks
#
# resource "aws_vpc_endpoint" "databricks_privatelink" {
#   vpc_id              = var.vpc_id
#   service_name        = "com.amazonaws.vpce.REGION.vpce-svc-xxxxx" # Get from Databricks
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = var.private_subnet_ids
#   security_group_ids  = var.security_group_ids # Use separate SG for PrivateLink
#   private_dns_enabled = false # Databricks uses custom DNS configuration
#
#   dns_options {
#     dns_record_ip_type = "ipv4"
#   }
#
#   tags = {
#     Name    = "vpce-databricks-${var.project_name}-${var.env}"
#     Service = "databricks-privatelink"
#     Tier    = "enterprise-privatelink"
#     Cost    = "~$14.40/month (2 AZs) + data transfer"
#   }
# }

# ============================================================================
# MODERN MONITORING & OBSERVABILITY
# ============================================================================
# VPC Endpoints provide CloudWatch metrics:
# - BytesIn/BytesOut: Data transfer volume
# - PacketsIn/PacketsOut: Network packet statistics
# - ActiveConnections: Current connection count
# - NewConnections: Rate of new connections
# - RejectedConnections: Failed connection attempts
#
# Interface endpoints also provide:
# - DNSQueries: Number of DNS queries resolved
# - EndpointNetworkInterfaces: Health of ENIs
#
# RECOMMENDED MONITORING:
# - Alert on RejectedConnections > 0 (security group issues)
# - Track BytesOut for cost optimization
# - Monitor ActiveConnections approaching limits
# - Set up CloudWatch dashboards for endpoint health
# - Use VPC Flow Logs to analyze endpoint traffic patterns
# ============================================================================
