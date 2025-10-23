# ============================================================================
# AWS Subnets Module - Databricks Network Segmentation
# ============================================================================
#
# PURPOSE:
# --------
# Creates private and public subnets across multiple availability zones for
# Databricks Premium tier deployments with high availability.
#
# SUBNET STRATEGY:
# ----------------
# PRIVATE SUBNETS (for Databricks workloads):
# - Minimum 2 subnets in different AZs (Databricks requirement)
# - Each subnet must be /26 or larger (minimum 64 IPs)
# - Hosts: Databricks clusters, driver nodes, worker nodes
# - No direct internet access (use NAT Gateway for egress)
# - Size recommendation: /26 for dev, /24 for staging, /22 for production
#
# PUBLIC SUBNETS (for NAT Gateways only):
# - One per AZ to match private subnets (high availability)
# - Can be small (/28 = 16 IPs) since only NAT Gateways use them
# - NO Databricks resources are placed here (security best practice)
# - Provides internet egress via NAT Gateway for private subnets
#
# HIGH AVAILABILITY:
# ------------------
# - Multi-AZ deployment prevents single AZ failure
# - Each private subnet gets its own NAT Gateway in corresponding AZ
# - If one AZ fails, workloads in other AZs continue operating
# - Required for production SLAs and Databricks best practices
#
# CIDR CALCULATION:
# -----------------
# Uses Terraform's cidrsubnet() function for deterministic IP allocation:
# - Private: cidrsubnet(vpc_cidr, newbits, 0-N) - starts from beginning
# - Public: cidrsubnet(vpc_cidr, newbits, 4+N) - offset to avoid overlap
# - Example: /24 VPC → /26 private (4 subnets max) + /28 public (16 subnets max)
#
# ENTERPRISE TIER NOTES:
# ----------------------
# With Databricks Enterprise + PrivateLink:
# - Private subnets: NO CHANGES (same configuration)
# - Public subnets: Can be eliminated entirely (no NAT Gateway needed)
# - All traffic routes through PrivateLink endpoint to control plane
# - Data plane remains in private subnets (this module still needed)
# - Ultimate security posture: zero internet exposure
#
# PRODUCTION SIZING GUIDELINES:
# ------------------------------
# Environment | VPC CIDR  | Private Subnet | Public Subnet | Max Clusters
# ------------|-----------|----------------|---------------|-------------
# Dev/Test    | /24       | /26 (64 IPs)   | /28 (16 IPs)  | ~5-10
# Staging     | /20       | /24 (256 IPs)  | /28 (16 IPs)  | ~50-100
# Production  | /16       | /22 (1024 IPs) | /27 (32 IPs)  | ~200-500
# Enterprise  | /16       | /20 (4096 IPs) | /27 (32 IPs)  | ~1000+
#
# ============================================================================

# Private subnets for Databricks workloads
# All compute resources (clusters, jobs, notebooks) run here
resource "aws_subnet" "private" {
  count                           = var.subnet_count
  vpc_id                          = var.vpc_id
  cidr_block                      = cidrsubnet(var.vpc_cidr_block, var.private_subnet_newbits, count.index)
  availability_zone               = var.availability_zones[count.index]
  map_public_ip_on_launch         = false # Never assign public IPs (security requirement)
  assign_ipv6_address_on_creation = false # Databricks doesn't require IPv6

  # Modern feature: Enable DNS64 for IPv6-only workloads (if needed in future)
  # enable_dns64                    = false
  # enable_resource_name_dns_a_record_on_launch = true

  tags = {
    Name = "sn-pvt-${var.project_name}-${var.env}-${var.availability_zones[count.index]}"
    Type = "private"
    Tier = "databricks-workload"
  }
}

# Public subnets for NAT Gateways
# NO Databricks workloads run here (NAT Gateways only)
resource "aws_subnet" "public" {
  count                           = var.subnet_count
  vpc_id                          = var.vpc_id
  cidr_block                      = cidrsubnet(var.vpc_cidr_block, var.public_subnet_newbits, count.index + 4) # Offset to avoid overlap
  availability_zone               = var.availability_zones[count.index]
  map_public_ip_on_launch         = true  # NAT Gateways need public IPs
  assign_ipv6_address_on_creation = false # Not required

  tags = {
    Name = "sn-pub-${var.project_name}-${var.env}-${var.availability_zones[count.index]}"
    Type = "public"
    Tier = "nat-gateway-only"
  }

  # ENTERPRISE TIER NOTE:
  # With PrivateLink, these public subnets can be eliminated entirely.
  # The public subnet resources would not be created, and NAT Gateway
  # module would be skipped. Control plane access moves to PrivateLink
  # endpoint in private subnets.
}
