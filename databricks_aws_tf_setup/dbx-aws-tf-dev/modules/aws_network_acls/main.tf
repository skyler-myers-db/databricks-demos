# ============================================================================
# AWS Network ACLs Module - Subnet-Level Access Control for Databricks
# ============================================================================
#
# PURPOSE:
# --------
# Creates Network ACLs (NACLs) that meet Databricks Premium tier requirements.
# NACLs provide stateless subnet-level firewall rules as required by Databricks.
#
# DATABRICKS PREMIUM TIER NACL REQUIREMENTS:
# -------------------------------------------
# Per https://docs.databricks.com/aws/security/customer-managed-vpc.html
#
# Egress (outbound) - MUST BE HIGHEST PRIORITY (lowest rule numbers):
#   - Allow all traffic to workspace VPC CIDR (internal traffic)
#   - Allow TCP to 0.0.0.0/0 on ports: 443, 3306, 6666, 8443, 8444, 8445-8451
#   - Allow ephemeral ports for return traffic
#
# Ingress (inbound):
#   - ALLOW ALL from 0.0.0.0/0 (required by Databricks - Rule 100)
#   - Why: Databricks control plane initiates connections from various IPs
#   - Control egress at firewall/proxy level, NOT via NACLs
#
# IMPORTANT NOTES:
# ----------------
# - NACLs are STATELESS (must allow return traffic explicitly)
# - Security Groups provide stateful filtering (primary security control)
# - NACLs are defense-in-depth, NOT primary security boundary
# - Databricks requires permissive NACLs, use SGs for granular control
# - Rule numbers: Lower = higher priority (evaluated in order)
# - Rule 32767 (default deny) applies if no match
#
# COST:
# -----
# Network ACLs are FREE (no charges for NACLs or rules)
#
# ============================================================================

# Get current region for service endpoints
data "aws_region" "current" {}

# ============================================================================
# NETWORK ACL FOR DATABRICKS PRIVATE SUBNETS
# ============================================================================
# Applied to all private subnets where Databricks clusters run

resource "aws_network_acl" "databricks_private" {
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "nacl-databricks-pvt-${var.project_name}-${var.env}"
    Type = "private"
    Tier = "databricks-premium-required"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# INGRESS RULES (INBOUND)
# ============================================================================

# Rule 100: Allow ALL inbound traffic (REQUIRED by Databricks)
# Databricks control plane initiates connections from various IPs
# Security is enforced via Security Groups, not NACLs
resource "aws_network_acl_rule" "ingress_allow_all" {
  network_acl_id = aws_network_acl.databricks_private.id
  rule_number    = 100
  egress         = false
  protocol       = "-1" # All protocols
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

# ============================================================================
# EGRESS RULES (OUTBOUND) - HIGHEST PRIORITY (Rules 100-199)
# ============================================================================
# These MUST be the lowest rule numbers to ensure Databricks connectivity

# Rule 100: Allow all traffic to VPC CIDR (internal cluster communication)
# Critical for cluster-to-cluster, cluster-to-endpoint communication
resource "aws_network_acl_rule" "egress_vpc_internal" {
  network_acl_id = aws_network_acl.databricks_private.id
  rule_number    = 100
  egress         = true
  protocol       = "-1" # All protocols
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr_block
}

# Rule 110: HTTPS (443) - Databricks infrastructure, libraries, data sources
# REQUIRED for control plane, PyPI, Maven, cloud data sources
resource "aws_network_acl_rule" "egress_https" {
  network_acl_id = aws_network_acl.databricks_private.id
  rule_number    = 110
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# Rule 120: MySQL (3306) - External Hive metastore
# Required if using external metastore (not Unity Catalog)
resource "aws_network_acl_rule" "egress_mysql" {
  network_acl_id = aws_network_acl.databricks_private.id
  rule_number    = 120
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 3306
  to_port        = 3306
}

# Rule 130: Port 6666 - Secure Cluster Connectivity (ONLY if using PrivateLink)
# Required for Enterprise tier with PrivateLink
resource "aws_network_acl_rule" "egress_privatelink_scc" {
  network_acl_id = aws_network_acl.databricks_private.id
  rule_number    = 130
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 6666
  to_port        = 6666
}

# Rule 140: Port 8443 - Internal compute plane to control plane API
# Critical for cluster lifecycle, job execution, notebook runs
resource "aws_network_acl_rule" "egress_control_plane" {
  network_acl_id = aws_network_acl.databricks_private.id
  rule_number    = 140
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 8443
  to_port        = 8443
}

# Rule 150: Port 8444 - Unity Catalog logging and lineage
# Required for Unity Catalog metadata and lineage tracking
resource "aws_network_acl_rule" "egress_unity_catalog" {
  network_acl_id = aws_network_acl.databricks_private.id
  rule_number    = 150
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 8444
  to_port        = 8444
}

# Rule 160: Ports 8445-8451 - Future Databricks features
# Reserved for future Databricks functionality
resource "aws_network_acl_rule" "egress_future_ports" {
  network_acl_id = aws_network_acl.databricks_private.id
  rule_number    = 160
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 8445
  to_port        = 8451
}

# Rule 170: DNS TCP (53) - Custom DNS resolution
# Required when using custom DNS servers
resource "aws_network_acl_rule" "egress_dns_tcp" {
  network_acl_id = aws_network_acl.databricks_private.id
  rule_number    = 170
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 53
  to_port        = 53
}

# Rule 180: DNS UDP (53) - Standard DNS resolution
# Most DNS queries use UDP
resource "aws_network_acl_rule" "egress_dns_udp" {
  network_acl_id = aws_network_acl.databricks_private.id
  rule_number    = 180
  egress         = true
  protocol       = "17" # UDP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 53
  to_port        = 53
}

# Rule 190: Ephemeral ports (1024-65535) - Return traffic
# CRITICAL: NACLs are STATELESS, must explicitly allow return traffic
# Covers: HTTP/S responses, SSH responses, database responses, API responses
resource "aws_network_acl_rule" "egress_ephemeral" {
  network_acl_id = aws_network_acl.databricks_private.id
  rule_number    = 190
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# Rule 191: Ephemeral ports UDP - Return traffic for UDP connections
resource "aws_network_acl_rule" "egress_ephemeral_udp" {
  network_acl_id = aws_network_acl.databricks_private.id
  rule_number    = 191
  egress         = true
  protocol       = "17" # UDP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# ============================================================================
# OPTIONAL: Additional Egress DENY Rules (Rules 200+)
# ============================================================================
# Add custom DENY rules here if needed, but ensure they're AFTER rule 190
# to avoid breaking Databricks connectivity
#
# Example: Block specific CIDR ranges while allowing Databricks traffic
# resource "aws_network_acl_rule" "egress_deny_example" {
#   network_acl_id = aws_network_acl.databricks_private.id
#   rule_number    = 200
#   egress         = true
#   protocol       = "-1"
#   rule_action    = "deny"
#   cidr_block     = "10.99.0.0/16"  # Example blocked range
# }

# ============================================================================
# NETWORK ACL FOR PUBLIC SUBNETS (NAT Gateway only)
# ============================================================================
# Simpler rules since only NAT Gateways reside here

resource "aws_network_acl" "public" {
  vpc_id     = var.vpc_id
  subnet_ids = var.public_subnet_ids

  tags = {
    Name = "nacl-pub-${var.project_name}-${var.env}"
    Type = "public"
    Tier = "nat-gateway-only"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Public subnet ingress: Allow ephemeral ports (return traffic from internet)
resource "aws_network_acl_rule" "public_ingress_ephemeral" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# Public subnet ingress: Allow traffic from VPC (NAT Gateway receives from private)
resource "aws_network_acl_rule" "public_ingress_vpc" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr_block
}

# Public subnet egress: Allow all outbound (NAT Gateway forwards to internet)
resource "aws_network_acl_rule" "public_egress_all" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

# ============================================================================
# ARCHITECTURE NOTES & BEST PRACTICES
# ============================================================================
#
# WHY NACLS ARE LAST LINE OF DEFENSE:
# ------------------------------------
# 1. Security Groups: Stateful, primary security control (cluster access)
# 2. Route Tables: Control routing paths (NAT, IGW, VPC endpoints)
# 3. Network ACLs: Stateless, subnet-level defense-in-depth
# 4. VPC Flow Logs: Audit trail for all network traffic
#
# NACL vs SECURITY GROUP:
# -----------------------
# Security Groups:
#   ✅ Stateful (return traffic automatic)
#   ✅ Instance/ENI level (granular)
#   ✅ Allow rules only (implicit deny)
#   ✅ Primary security boundary
#
# Network ACLs:
#   ⚠️  Stateless (must allow return traffic)
#   ⚠️  Subnet level (broader scope)
#   ⚠️  Allow AND deny rules
#   ⚠️  Secondary defense layer
#
# MONITORING NACL EFFECTIVENESS:
# -------------------------------
# - VPC Flow Logs: See rejected packets at NACL level
# - CloudWatch Insights: Query flow logs for NACL denies
# - Filter pattern: "REJECT" to see blocked traffic
# - Regular review: Ensure no legitimate traffic blocked
#
# TROUBLESHOOTING NACL ISSUES:
# -----------------------------
# 1. Check rule order (lowest number = highest priority)
# 2. Verify ephemeral ports allowed (1024-65535)
# 3. Remember NACLs are stateless (both directions needed)
# 4. Test with VPC Reachability Analyzer
# 5. Review VPC Flow Logs for rejected packets
#
# COMPLIANCE BENEFITS:
# --------------------
# ✅ CIS AWS Foundations: Network segmentation
# ✅ NIST 800-53 SC-7: Boundary protection
# ✅ PCI-DSS: Network isolation requirements
# ✅ HIPAA: Technical safeguards
# ✅ SOC 2: Access control measures
# ✅ Databricks Premium: Official requirements met
#
# COST OPTIMIZATION:
# ------------------
# NACLs are completely FREE. No charges for:
# - Number of NACLs
# - Number of rules per NACL
# - Rule evaluations
# - Associated subnets
#
# ============================================================================
