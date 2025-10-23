# ============================================================================
# AWS Route Tables Module - Network Traffic Control for Databricks
# ============================================================================
#
# PURPOSE:
# --------
# Creates and manages route tables for public and private subnets, directing
# network traffic to the appropriate gateways (Internet Gateway or NAT Gateway)
# based on subnet type and security requirements.
#
# ROUTING ARCHITECTURE:
# ---------------------
#
# PUBLIC ROUTE TABLE (Single shared table):
# - Used by public subnets (NAT Gateway placement only)
# - Routes all internet traffic (0.0.0.0/0) to Internet Gateway
# - Shared across all public subnets (no cross-AZ routing needed)
# - Only NAT Gateways use this table (no Databricks workloads)
#
# PRIVATE ROUTE TABLES (One per AZ):
# - Used by private subnets (Databricks workloads)
# - Routes internet traffic (0.0.0.0/0) to NAT Gateway in same AZ
# - Separate table per AZ prevents cross-AZ data transfer charges
# - Local VPC routes are implicit (always highest priority)
# - VPC Endpoints add automatic routes (handled by AWS)
#
# HIGH AVAILABILITY DESIGN:
# --------------------------
# Multi-AZ routing strategy:
# - Each private subnet in AZ-A routes through NAT Gateway in AZ-A
# - Each private subnet in AZ-B routes through NAT Gateway in AZ-B
# - If AZ-A fails, workloads in AZ-B continue with no routing changes
# - Prevents cascading failures across availability zones
# - Eliminates cross-AZ data transfer costs during normal operation
#
# ROUTE PRIORITY:
# ---------------
# AWS evaluates routes in this order (most specific to least):
# 1. Local VPC routes (automatic, highest priority)
# 2. VPC Endpoint routes (automatic when endpoints created)
# 3. Custom static routes (what we define here)
# 4. Propagated routes (if using VPN/Direct Connect)
#
# COST OPTIMIZATION:
# ------------------
# - Same-AZ routing: No cross-AZ data transfer charges ($0.01/GB savings)
# - VPC Endpoints: Bypass NAT Gateway for AWS services (reduces NAT costs)
# - Gateway endpoints (S3): FREE routing, no data charges
# - Interface endpoints (STS, Kinesis): $0.01/GB vs $0.045/GB through NAT
#
# SECURITY CONSIDERATIONS:
# ------------------------
# - Private subnets: No direct internet access (defense in depth)
# - Public subnets: Only accessible by NAT Gateways (not Databricks)
# - All routes logged via VPC Flow Logs (compliance requirement)
# - No routes to 0.0.0.0/0 from private subnets except via NAT
# - Local traffic never leaves VPC (AWS backbone routing)
#
# ENTERPRISE TIER WITH PRIVATELINK:
# ----------------------------------
# With Databricks Enterprise + AWS PrivateLink:
# - Public route table: Can be eliminated (no NAT Gateways needed)
# - Private route tables: Still required for VPC traffic
# - 0.0.0.0/0 routes: Can be removed for fully air-gapped deployment
# - VPC Endpoint routes: Automatically added by AWS (S3, STS, Kinesis, etc.)
# - PrivateLink routes: Automatically added when endpoint created
# - Result: Zero internet routing, all traffic stays in AWS private network
#
# MODERN FEATURES (2024-2025):
# -----------------------------
# - Support for VPC Peering connections (can add routes to peered VPCs)
# - Transit Gateway integration (multi-VPC routing)
# - Route table analysis via VPC Reachability Analyzer
# - Automatic propagation from VPN/Direct Connect
# - IPv6 routing support (not used by Databricks currently)
#
# ============================================================================

# ============================================================================
# PUBLIC ROUTE TABLE (Shared by all public subnets)
# ============================================================================
# Single route table for all public subnets
# Only routes internet traffic to Internet Gateway
# Used exclusively by NAT Gateways (no Databricks resources)

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  tags = {
    Name = "rt-pub-${var.project_name}-${var.env}"
    Type = "public"
    Tier = "nat-gateway-only"
  }
}

# Default route to Internet Gateway for public subnets
# Enables NAT Gateways to send/receive internet traffic
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.internet_gateway_id

  # Modern best practice: Use timeouts for large route table operations
  timeouts {
    create = "5m"
    delete = "5m"
  }
}

# Associate public subnets with public route table
# Each public subnet (NAT Gateway placement) uses this shared table
resource "aws_route_table_association" "public" {
  count          = var.subnet_count
  subnet_id      = var.public_subnet_ids[count.index]
  route_table_id = aws_route_table.public.id
}

# ============================================================================
# PRIVATE ROUTE TABLES (One per Availability Zone)
# ============================================================================
# Separate route table per AZ for high availability and cost optimization
# Each routes internet traffic through NAT Gateway in same AZ
# Prevents cross-AZ data transfer charges and single point of failure

resource "aws_route_table" "private" {
  count  = var.subnet_count
  vpc_id = var.vpc_id

  tags = {
    Name = "rt-pvt-${var.project_name}-${var.env}-${var.availability_zones[count.index]}"
    Type = "private"
    AZ   = var.availability_zones[count.index]
    Tier = "databricks-workload"
  }
}

# Default route to NAT Gateway for private subnets (one per AZ)
# Provides secure internet egress for Databricks clusters
resource "aws_route" "private_nat" {
  count                  = var.subnet_count
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_ids[count.index]

  # Modern best practice: Use timeouts for large route table operations
  timeouts {
    create = "5m"
    delete = "5m"
  }

  # ENTERPRISE TIER NOTE:
  # With PrivateLink, this route becomes optional. For fully air-gapped
  # deployments, this 0.0.0.0/0 route can be removed entirely. Traffic
  # would then only flow through VPC Endpoints (S3, STS, Kinesis) and
  # PrivateLink endpoint (control plane). No internet egress required.
}

# Associate private subnets with their respective private route tables
# Each private subnet uses the route table in its own AZ (HA + cost optimization)
resource "aws_route_table_association" "private" {
  count          = var.subnet_count
  subnet_id      = var.private_subnet_ids[count.index]
  route_table_id = aws_route_table.private[count.index].id
}

# ============================================================================
# OPTIONAL: VPC ENDPOINT ROUTES (Gateway Endpoints)
# ============================================================================
# Note: Gateway endpoints (S3) automatically add routes to route tables
# when associated. No explicit route resources needed here.
# The VPC endpoints module will handle the route table associations.
#
# Interface endpoints (STS, Kinesis, EC2) use security groups and DNS,
# not route table entries. They automatically work via private DNS.
# ============================================================================

# ============================================================================
# MODERN MONITORING & VALIDATION
# ============================================================================
# Route tables automatically integrate with:
# - VPC Flow Logs: All routed traffic is logged
# - VPC Reachability Analyzer: Test connectivity paths
# - Network Access Analyzer: Find unintended network access
# - CloudWatch Insights: Query flow logs for routing issues
#
# VALIDATION CHECKLIST:
# - Verify each private subnet has route to NAT Gateway
# - Confirm public subnets route to Internet Gateway
# - Check VPC Endpoint routes are automatically added
# - Validate no direct internet routes from private subnets
# - Test failover behavior if one AZ goes down
# ============================================================================
