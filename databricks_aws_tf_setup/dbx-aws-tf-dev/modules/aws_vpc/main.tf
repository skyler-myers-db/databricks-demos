# ============================================================================
# AWS VPC Module - Core Network Foundation for Databricks
# ============================================================================
#
# PURPOSE:
# --------
# This module creates the foundational VPC with security and observability
# features required for enterprise-grade Databricks deployments.
#
# FEATURES:
# ---------
# - VPC with configurable CIDR block
# - DNS resolution and hostnames enabled (required for VPC endpoints)
# - Network address usage metrics (AWS IPAM integration)
# - VPC Flow Logs for security monitoring and compliance
# - CloudWatch Logs integration for flow log analysis
# - IAM roles and policies for flow log publishing
#
# PRODUCTION CONSIDERATIONS:
# ---------------------------
# - Use /16 to /20 CIDR blocks for production (not /24)
# - Enable VPC Flow Logs in all environments (security requirement)
# - Consider S3 destination for flow logs in production (lower cost)
# - Retention: 7 days for dev, 30-90 days for production
# - Flow logs can be analyzed with CloudWatch Insights or Athena
#
# ENTERPRISE TIER NOTES:
# ----------------------
# With Databricks Enterprise + PrivateLink:
# - VPC design remains the same (this module unchanged)
# - Control plane communication moves to PrivateLink (see vpc_endpoints module)
# - Can eliminate NAT Gateway/IGW for fully air-gapped deployments
# - Required for strictest compliance frameworks (HIPAA, PCI-DSS Level 1)
#
# ============================================================================

# Get available AZs in the region for subnet placement
data "aws_availability_zones" "available" {
  state = "available"
}

# Get current region for VPC endpoint service names
data "aws_region" "current" {}

# Core VPC Resource
resource "aws_vpc" "this" {
  cidr_block                           = var.vpc_cidr_block
  enable_dns_support                   = true  # Required for VPC endpoints
  enable_dns_hostnames                 = true  # Required for VPC endpoints
  enable_network_address_usage_metrics = true  # AWS IPAM integration (Oct 2023+)
  assign_generated_ipv6_cidr_block     = false # Databricks doesn't require IPv6

  tags = {
    Name = "vpc-${var.project_name}-${var.env}"
  }
}

# ============================================================================
# VPC Flow Logs - Security & Compliance Best Practice
# ============================================================================
# Captures all IP traffic for security analysis, troubleshooting, compliance.
# Required by most security frameworks (CIS, NIST, SOC2, ISO 27001).
#
# COST OPTIMIZATION:
# - Dev: CloudWatch Logs (this config) ~$0.50/GB ingestion
# - Prod: Consider S3 destination ~$0.023/GB (10x cheaper)
# - Can filter to reject logs (ALL, ACCEPT, REJECT) to reduce volume
#
# MODERN FEATURES (2024-2025):
# - Support for Transit Gateway flow logs
# - Enhanced metadata fields (TCP flags, pkt-src/dst-addr)
# - Direct delivery to S3 in Parquet format (cheaper queries)
# ============================================================================

resource "aws_flow_log" "vpc" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL" # Options: ALL, ACCEPT, REJECT
  vpc_id          = aws_vpc.this.id

  # Optional: Add custom log format for enhanced monitoring
  # log_format = "$${account-id} $${action} $${bytes} $${dstaddr} $${dstport} $${end} $${flow-direction} $${instance-id} $${interface-id} $${log-status} $${packets} $${pkt-dstaddr} $${pkt-srcaddr} $${protocol} $${srcaddr} $${srcport} $${start} $${tcp-flags} $${traffic-path} $${type} $${vpc-id}"

  tags = {
    Name = "flowlog-${var.project_name}-${var.env}"
  }
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flowlogs-${var.project_name}-${var.env}"
  retention_in_days = var.flow_logs_retention_days

  # Modern feature: Log class for cost optimization
  # STANDARD = full features, INFREQUENT_ACCESS = 50% cheaper (Nov 2023+)
  log_group_class = var.env == "prod" ? "STANDARD" : "INFREQUENT_ACCESS"

  tags = {
    Name = "flowlogs-${var.project_name}-${var.env}"
  }
}

# IAM Role for VPC Flow Logs
# Allows VPC Flow Logs service to write to CloudWatch
resource "aws_iam_role" "flow_logs" {
  name = "vpc-flowlogs-${var.project_name}-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowVPCFlowLogsAssumeRole"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:ec2:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:vpc-flow-log/*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "vpc-flowlogs-role-${var.project_name}-${var.env}"
  }
}

# Get current AWS account ID for IAM policy conditions
data "aws_caller_identity" "current" {}

# IAM Policy for VPC Flow Logs to write to CloudWatch
# Modern best practice: Least privilege with resource-specific permissions
resource "aws_iam_role_policy" "flow_logs" {
  name = "vpc-flowlogs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowFlowLogsToCloudWatch"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect = "Allow"
        # Best practice: Scope to specific log group
        Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
      }
    ]
  })
}
