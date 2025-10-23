# ============================================================================
# Gateway Endpoint Outputs (S3)
# ============================================================================

output "s3_endpoint_id" {
  description = "The ID of the S3 gateway endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "s3_endpoint_arn" {
  description = "The ARN of the S3 gateway endpoint"
  value       = aws_vpc_endpoint.s3.arn
}

output "s3_endpoint_prefix_list_id" {
  description = "The prefix list ID of the S3 gateway endpoint (for security group rules)"
  value       = aws_vpc_endpoint.s3.prefix_list_id
}

output "s3_endpoint_cidr_blocks" {
  description = "The CIDR blocks for the S3 service"
  value       = aws_vpc_endpoint.s3.cidr_blocks
}

# ============================================================================
# Interface Endpoint Outputs (STS, Kinesis, EC2)
# ============================================================================

output "sts_endpoint_id" {
  description = "The ID of the STS interface endpoint"
  value       = aws_vpc_endpoint.sts.id
}

output "sts_endpoint_arn" {
  description = "The ARN of the STS interface endpoint"
  value       = aws_vpc_endpoint.sts.arn
}

output "sts_endpoint_dns_entries" {
  description = "The DNS entries for the STS interface endpoint"
  value       = aws_vpc_endpoint.sts.dns_entry
}

output "sts_endpoint_network_interface_ids" {
  description = "The ENI IDs created for the STS interface endpoint"
  value       = aws_vpc_endpoint.sts.network_interface_ids
}

output "kinesis_endpoint_id" {
  description = "The ID of the Kinesis Streams interface endpoint"
  value       = aws_vpc_endpoint.kinesis.id
}

output "kinesis_endpoint_arn" {
  description = "The ARN of the Kinesis Streams interface endpoint"
  value       = aws_vpc_endpoint.kinesis.arn
}

output "kinesis_endpoint_dns_entries" {
  description = "The DNS entries for the Kinesis Streams interface endpoint"
  value       = aws_vpc_endpoint.kinesis.dns_entry
}

output "kinesis_endpoint_network_interface_ids" {
  description = "The ENI IDs created for the Kinesis Streams interface endpoint"
  value       = aws_vpc_endpoint.kinesis.network_interface_ids
}

output "ec2_endpoint_id" {
  description = "The ID of the EC2 interface endpoint"
  value       = aws_vpc_endpoint.ec2.id
}

output "ec2_endpoint_arn" {
  description = "The ARN of the EC2 interface endpoint"
  value       = aws_vpc_endpoint.ec2.arn
}

output "ec2_endpoint_dns_entries" {
  description = "The DNS entries for the EC2 interface endpoint"
  value       = aws_vpc_endpoint.ec2.dns_entry
}

output "ec2_endpoint_network_interface_ids" {
  description = "The ENI IDs created for the EC2 interface endpoint"
  value       = aws_vpc_endpoint.ec2.network_interface_ids
}

# ============================================================================
# Summary Outputs
# ============================================================================

output "all_endpoint_ids" {
  description = "List of all VPC endpoint IDs created by this module"
  value = [
    aws_vpc_endpoint.s3.id,
    aws_vpc_endpoint.sts.id,
    aws_vpc_endpoint.kinesis.id,
    aws_vpc_endpoint.ec2.id
  ]
}

output "gateway_endpoint_ids" {
  description = "List of gateway endpoint IDs (S3)"
  value       = [aws_vpc_endpoint.s3.id]
}

output "interface_endpoint_ids" {
  description = "List of interface endpoint IDs (STS, Kinesis, EC2)"
  value = [
    aws_vpc_endpoint.sts.id,
    aws_vpc_endpoint.kinesis.id,
    aws_vpc_endpoint.ec2.id
  ]
}

# Cost estimation output
output "estimated_monthly_cost" {
  description = "Estimated monthly cost for interface endpoints (excludes data transfer). Gateway endpoints (S3) are FREE."
  value = format(
    "Interface endpoints: ~$%.2f/month (base) + data transfer charges. Gateway endpoints: $0 (FREE)",
    (length(var.private_subnet_ids) * 7.20) * 3 # STS, Kinesis, EC2
  )
}

# ============================================================================
# OPTIONAL: Enterprise Tier PrivateLink Outputs
# ============================================================================
# Uncomment when enabling Databricks PrivateLink
#
# output "databricks_privatelink_endpoint_id" {
#   description = "The ID of the Databricks PrivateLink endpoint"
#   value       = var.enable_databricks_privatelink ? aws_vpc_endpoint.databricks_privatelink[0].id : null
# }
#
# output "databricks_privatelink_endpoint_arn" {
#   description = "The ARN of the Databricks PrivateLink endpoint"
#   value       = var.enable_databricks_privatelink ? aws_vpc_endpoint.databricks_privatelink[0].arn : null
# }
#
# output "databricks_privatelink_dns_entries" {
#   description = "The DNS entries for the Databricks PrivateLink endpoint"
#   value       = var.enable_databricks_privatelink ? aws_vpc_endpoint.databricks_privatelink[0].dns_entry : []
# }
