# ============================================================================
# AWS Internet Gateway Module - Public Internet Access Foundation
# ============================================================================
#
# PURPOSE:
# --------
# Creates an Internet Gateway (IGW) that provides internet connectivity for
# resources in public subnets. For Databricks Premium tier, this enables
# NAT Gateways to provide egress internet access for private subnet workloads.
#
# ARCHITECTURE ROLE:
# ------------------
# Internet Gateway sits at the VPC edge and provides:
# - Inbound internet access to public subnet resources (NAT Gateways only)
# - Outbound internet access from public subnets (NAT Gateway egress)
# - NOT directly accessible by Databricks workloads (security by design)
#
# SECURITY DESIGN:
# ----------------
# For Databricks Premium tier:
# - IGW only used by NAT Gateways in public subnets
# - No Databricks compute resources have direct IGW access
# - Databricks clusters in private subnets route through NAT Gateway
# - Defense-in-depth: Network segmentation prevents direct internet exposure
#
# HIGH AVAILABILITY:
# ------------------
# - IGW is inherently redundant and highly available within AWS
# - No single point of failure (AWS-managed service)
# - Scales automatically with traffic (no capacity planning needed)
# - 99.99% availability SLA from AWS
#
# COST:
# -----
# - No hourly charge for Internet Gateway itself (FREE resource)
# - Data transfer charges apply:
#   - Ingress: FREE (all inbound traffic)
#   - Egress: $0.09/GB to internet (first 10TB/month in us-east-1)
#   - Regional data transfer: varies by region
#
# ENTERPRISE TIER ALTERNATIVE:
# -----------------------------
# With Databricks Enterprise + AWS PrivateLink:
# - Internet Gateway becomes OPTIONAL (can be eliminated entirely)
# - PrivateLink endpoint provides direct private connection to control plane
# - All AWS service access via VPC endpoints (S3, STS, Kinesis)
# - External integrations (PyPI, Git, APIs) can still use NAT+IGW if needed
# - OR use AWS Services like CodeArtifact, CodeCommit for full air-gap
# - Ultimate security: Zero internet exposure possible with PrivateLink
#
# COMPLIANCE CONSIDERATIONS:
# --------------------------
# - Required for: Standard cloud deployments with internet egress
# - Optional for: Air-gapped/restricted environments with PrivateLink
# - Audit trail: All traffic logged via VPC Flow Logs
# - HIPAA/PCI-DSS: Acceptable with proper network segmentation
# - FedRAMP/Gov: May require PrivateLink for highest security levels
#
# ============================================================================

resource "aws_internet_gateway" "this" {
  vpc_id = var.vpc_id

  tags = {
    Name = "igw-${var.project_name}-${var.env}"
    Tier = "premium-standard"
    Note = "With Enterprise tier + PrivateLink, this IGW can be eliminated for fully private connectivity"
  }

  # MODERN BEST PRACTICE (2024-2025):
  # Consider adding lifecycle hooks for graceful deletion
  lifecycle {
    create_before_destroy = true
  }
}
