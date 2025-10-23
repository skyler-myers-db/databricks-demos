# ============================================================================
# DATABRICKS WORKSPACE SECURITY GROUP OUTPUTS
# ============================================================================

output "databricks_workspace_security_group_id" {
  description = "The ID of the Databricks workspace security group (attach to clusters)"
  value       = aws_security_group.databricks_workspace.id
}

output "databricks_workspace_security_group_arn" {
  description = "The ARN of the Databricks workspace security group"
  value       = aws_security_group.databricks_workspace.arn
}

output "databricks_workspace_security_group_name" {
  description = "The name of the Databricks workspace security group"
  value       = aws_security_group.databricks_workspace.name
}

# ============================================================================
# VPC ENDPOINTS SECURITY GROUP OUTPUTS
# ============================================================================

output "vpc_endpoints_security_group_id" {
  description = "The ID of the security group for VPC Interface Endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "vpc_endpoints_security_group_arn" {
  description = "The ARN of the security group for VPC Interface Endpoints"
  value       = aws_security_group.vpc_endpoints.arn
}

output "vpc_endpoints_security_group_name" {
  description = "The name of the security group for VPC Interface Endpoints"
  value       = aws_security_group.vpc_endpoints.name
}

output "vpc_endpoints_security_group_vpc_id" {
  description = "The VPC ID the security group belongs to"
  value       = aws_security_group.vpc_endpoints.vpc_id
}

# Convenient output for VPC endpoint module consumption
output "vpc_endpoint_security_group_ids" {
  description = "List of security group IDs for VPC endpoints (currently single SG, but prepared for multiple)"
  value       = [aws_security_group.vpc_endpoints.id]
}

# Convenient output for Databricks workspace module consumption
output "all_security_group_ids" {
  description = "All security group IDs to attach to Databricks workspace (workspace + endpoint SGs)"
  value       = [aws_security_group.databricks_workspace.id]
}

# ============================================================================
# OPTIONAL OUTPUTS: For Databricks PrivateLink (Enterprise Tier)
# ============================================================================
# Uncomment these when enabling PrivateLink security group
#
# output "databricks_privatelink_security_group_id" {
#   description = "The ID of the security group for Databricks PrivateLink endpoint"
#   value       = var.enable_privatelink_sg ? aws_security_group.databricks_privatelink[0].id : null
# }
#
# output "databricks_privatelink_security_group_arn" {
#   description = "The ARN of the security group for Databricks PrivateLink endpoint"
#   value       = var.enable_privatelink_sg ? aws_security_group.databricks_privatelink[0].arn : null
# }
#
# output "all_security_group_ids" {
#   description = "All security group IDs created by this module"
#   value       = var.enable_privatelink_sg ? [
#     aws_security_group.vpc_endpoints.id,
#     aws_security_group.databricks_privatelink[0].id
#   ] : [aws_security_group.vpc_endpoints.id]
# }
