output "public_route_table_id" {
  description = "The ID of the public route table (shared by all public subnets)"
  value       = aws_route_table.public.id
}

output "public_route_table_arn" {
  description = "The ARN of the public route table"
  value       = aws_route_table.public.arn
}

output "private_route_table_ids" {
  description = "List of private route table IDs (one per AZ)"
  value       = aws_route_table.private[*].id
}

output "private_route_table_arns" {
  description = "List of private route table ARNs"
  value       = aws_route_table.private[*].arn
}

output "public_route_table_association_ids" {
  description = "List of public route table association IDs"
  value       = aws_route_table_association.public[*].id
}

output "private_route_table_association_ids" {
  description = "List of private route table association IDs"
  value       = aws_route_table_association.private[*].id
}

# Convenience outputs for module consumers
output "all_route_table_ids" {
  description = "Combined list of all route table IDs (public + private)"
  value       = concat([aws_route_table.public.id], aws_route_table.private[*].id)
}

# Map of AZ to private route table ID for easy lookup
output "private_route_table_by_az" {
  description = "Map of availability zone to private route table ID"
  value = zipmap(
    var.availability_zones,
    aws_route_table.private[*].id
  )
}

# Useful for VPC endpoint gateway associations (S3)
output "private_route_table_ids_for_endpoints" {
  description = "List of private route table IDs for VPC Gateway Endpoint associations (e.g., S3)"
  value       = aws_route_table.private[*].id
}
