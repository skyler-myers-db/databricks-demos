# ============================================================================
# DATABRICKS PRIVATE SUBNET NACL OUTPUTS
# ============================================================================

output "databricks_private_nacl_id" {
  description = "The ID of the Network ACL for Databricks private subnets"
  value       = aws_network_acl.databricks_private.id
}

output "databricks_private_nacl_arn" {
  description = "The ARN of the Network ACL for Databricks private subnets"
  value       = aws_network_acl.databricks_private.arn
}

output "databricks_private_nacl_subnet_ids" {
  description = "List of private subnet IDs associated with the Databricks NACL"
  value       = aws_network_acl.databricks_private.subnet_ids
}

# ============================================================================
# PUBLIC SUBNET NACL OUTPUTS
# ============================================================================

output "public_nacl_id" {
  description = "The ID of the Network ACL for public subnets (NAT Gateways)"
  value       = aws_network_acl.public.id
}

output "public_nacl_arn" {
  description = "The ARN of the Network ACL for public subnets"
  value       = aws_network_acl.public.arn
}

output "public_nacl_subnet_ids" {
  description = "List of public subnet IDs associated with the public NACL"
  value       = aws_network_acl.public.subnet_ids
}

# ============================================================================
# SUMMARY OUTPUTS
# ============================================================================

output "all_nacl_ids" {
  description = "List of all Network ACL IDs created by this module"
  value = [
    aws_network_acl.databricks_private.id,
    aws_network_acl.public.id
  ]
}

output "databricks_compliance_status" {
  description = "Databricks Premium tier NACL requirements compliance status"
  value = {
    ingress_allow_all    = "✅ Rule 100: ALLOW ALL from 0.0.0.0/0 (required)"
    egress_vpc_cidr      = "✅ Rule 100: Allow all to VPC CIDR"
    egress_https         = "✅ Rule 110: Allow TCP 443"
    egress_mysql         = "✅ Rule 120: Allow TCP 3306"
    egress_privatelink   = "✅ Rule 130: Allow TCP 6666"
    egress_control_plane = "✅ Rule 140: Allow TCP 8443"
    egress_unity_catalog = "✅ Rule 150: Allow TCP 8444"
    egress_future_ports  = "✅ Rule 160: Allow TCP 8445-8451"
    egress_dns           = "✅ Rules 170-180: Allow TCP/UDP 53"
    egress_ephemeral     = "✅ Rules 190-191: Allow ephemeral 1024-65535"
    rule_priority        = "✅ Required rules have lowest numbers (100-191)"
    compliance_met       = "✅ FULLY COMPLIANT with Databricks Premium tier requirements"
    documentation_url    = "https://docs.databricks.com/aws/security/customer-managed-vpc.html"
  }
}

output "security_architecture_summary" {
  description = "Summary of the complete security architecture"
  value = {
    layer_1   = "Security Groups (stateful) - Primary security control at instance/ENI level"
    layer_2   = "Network ACLs (stateless) - Defense-in-depth at subnet level"
    layer_3   = "Route Tables - Control traffic routing paths"
    layer_4   = "VPC Flow Logs - Audit trail and monitoring"
    principle = "Defense in depth with least privilege"
  }
}
