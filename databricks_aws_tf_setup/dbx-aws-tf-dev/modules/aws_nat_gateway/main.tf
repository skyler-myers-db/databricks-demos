# ============================================================================
# AWS NAT Gateway Module - Secure Internet Egress for Databricks
# ============================================================================
#
# PURPOSE:
# --------
# Creates NAT Gateways with Elastic IPs to provide secure, managed internet
# egress for Databricks workloads in private subnets. Essential for external
# integrations while maintaining security best practices.
#
# ARCHITECTURE:
# -------------
# High Availability Multi-AZ Design:
# - One NAT Gateway per Availability Zone (prevents single point of failure)
# - Each NAT Gateway placed in corresponding public subnet
# - Each private subnet routes through NAT Gateway in same AZ
# - If one AZ fails, only workloads in that AZ are affected
#
# WHY NAT GATEWAY IS REQUIRED (Premium Tier):
# --------------------------------------------
# Databricks clusters in private subnets need internet access for:
# 1. PyPI package installation (pip install)
# 2. Git repository access (GitHub, GitLab, Bitbucket)
# 3. External APIs and webhooks
# 4. Maven/JAR dependencies for Spark
# 5. Docker image pulls (custom containers)
# 6. Certificate revocation list (CRL) checks
# 7. Third-party integrations (Slack, PagerDuty, etc.)
#
# SECURITY BENEFITS:
# ------------------
# - Outbound-only internet access (no inbound connections possible)
# - Single controlled egress point (easier to monitor and audit)
# - Private IPs for all Databricks resources (never exposed to internet)
# - Compatible with network firewalls for additional filtering
# - VPC Flow Logs capture all traffic for security analysis
#
# HIGH AVAILABILITY DESIGN:
# --------------------------
# Multi-AZ NAT ensures:
# - 99.95% availability SLA (per AZ)
# - No cross-AZ data transfer charges for normal operation
# - Automatic failover if AZ becomes unavailable
# - Independent scaling per AZ based on traffic
#
# COST CONSIDERATIONS:
# --------------------
# NAT Gateway Costs (as of Oct 2025):
# - Hourly charge: ~$0.045/hour = ~$32/month per NAT Gateway
# - Data processing: ~$0.045/GB processed
# - For 2 AZs: ~$64/month base + data charges
#
# Cost Optimization Strategies:
# 1. Use VPC Endpoints for AWS services (bypass NAT for S3, STS, Kinesis)
# 2. Cache packages in S3 or CodeArtifact (reduce external downloads)
# 3. Consider single NAT Gateway for dev/test (not recommended for prod)
# 4. Use EC2 Instance Connect Endpoint instead of bastion (reduces NAT traffic)
#
# Example Monthly Cost (2 AZ deployment):
# - 2x NAT Gateway: $64/month
# - 100GB data: $4.50/month
# - Total: ~$68.50/month
#
# ENTERPRISE TIER ALTERNATIVE:
# -----------------------------
# With Databricks Enterprise + AWS PrivateLink:
# - NAT Gateway becomes OPTIONAL (not eliminated entirely)
# - PrivateLink handles control plane communication (no NAT needed)
# - NAT still useful for external integrations (PyPI, Git, APIs)
# - Can eliminate NAT for fully air-gapped deployments using:
#   - AWS CodeArtifact (private PyPI mirror)
#   - AWS CodeCommit (private Git)
#   - VPC Endpoints for all AWS services
#   - S3 for pre-staged dependencies
#
# PRIVATELINK + NO NAT SCENARIO:
# - Ultimate security posture (zero internet exposure)
# - Required for air-gapped/classified environments
# - Higher operational overhead (must manage private mirrors)
# - Typically adds ~$100-200/month for private repository services
#
# MODERN FEATURES (2024-2025):
# -----------------------------
# - Enhanced monitoring with CloudWatch NAT Gateway metrics
# - Integration with Network Firewall for advanced threat detection
# - Support for secondary private IP addresses (increased connection limits)
# - IPv6 egress-only internet gateway as alternative (future consideration)
#
# ============================================================================

# Elastic IPs for NAT Gateways
# Static public IPs that persist across NAT Gateway recreations
# Important: Whitelist these IPs with external services/APIs
resource "aws_eip" "nat" {
  count  = var.subnet_count
  domain = "vpc" # Modern syntax (replaces deprecated 'vpc = true')

  tags = {
    Name = "eip-nat-${var.project_name}-${var.env}-${var.availability_zones[count.index]}"
    AZ   = var.availability_zones[count.index]
    Type = "nat-gateway"
  }

  # IMPORTANT: EIPs must be created after IGW exists
  depends_on = [var.internet_gateway_id]
}

# NAT Gateways in public subnets (one per AZ for high availability)
# Provides managed, highly available internet egress for private subnets
resource "aws_nat_gateway" "this" {
  count         = var.subnet_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = var.public_subnet_ids[count.index]

  # Modern feature: Configure connectivity type
  connectivity_type = "public" # Options: "public" or "private"

  tags = {
    Name = "nat-${var.project_name}-${var.env}-${var.availability_zones[count.index]}"
    AZ   = var.availability_zones[count.index]
    Tier = "premium-standard"
    Note = "With Enterprise tier + PrivateLink, NAT Gateway is optional. Can be eliminated for fully air-gapped deployments."
  }

  # CRITICAL: NAT Gateway requires IGW to be attached to VPC first
  depends_on = [var.internet_gateway_id]

  # Modern best practice: Ensure graceful recreation
  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# MODERN MONITORING & OBSERVABILITY (2024-2025 Best Practices)
# ============================================================================
# NAT Gateway provides these CloudWatch metrics automatically:
# - BytesInFromDestination: Traffic from internet to private subnets
# - BytesInFromSource: Traffic from private subnets to NAT Gateway
# - BytesOutToDestination: Traffic from NAT Gateway to internet
# - BytesOutToSource: Traffic from NAT Gateway to private subnets
# - PacketsInFromDestination: Inbound packet count
# - PacketsInFromSource: Outbound packet count
# - PacketsOutToDestination: Packets to internet
# - PacketsOutToSource: Packets to private subnets
# - ErrorPortAllocation: Failed connection attempts (port exhaustion)
# - ActiveConnectionCount: Current active connections
# - ConnectionAttemptCount: New connection attempts
# - ConnectionEstablishedCount: Successfully established connections
# - IdleTimeoutCount: Connections closed due to idle timeout
#
# ALERTING RECOMMENDATIONS:
# - Alert on ErrorPortAllocation > 0 (indicates capacity issues)
# - Alert on ActiveConnectionCount approaching limits (55,000 per NAT GW)
# - Monitor BytesOut for unexpected traffic spikes (potential data exfil)
# - Track monthly costs via CostExplorer (NAT Gateway can be expensive)
#
# Consider adding CloudWatch Alarms in a separate monitoring module
# ============================================================================
