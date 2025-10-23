output "private_subnet_ids" {
  description = "List of private subnet IDs for Databricks workloads"
  value       = aws_subnet.private[*].id
}

output "private_subnet_arns" {
  description = "List of private subnet ARNs"
  value       = aws_subnet.private[*].arn
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

output "private_subnet_availability_zones" {
  description = "List of availability zones for private subnets"
  value       = aws_subnet.private[*].availability_zone
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (NAT Gateway placement only)"
  value       = aws_subnet.public[*].id
}

output "public_subnet_arns" {
  description = "List of public subnet ARNs"
  value       = aws_subnet.public[*].arn
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "public_subnet_availability_zones" {
  description = "List of availability zones for public subnets"
  value       = aws_subnet.public[*].availability_zone
}

# Convenience outputs for module consumers
output "subnet_count" {
  description = "Number of subnet pairs created"
  value       = var.subnet_count
}

output "all_subnet_ids" {
  description = "Combined list of all subnet IDs (private + public)"
  value       = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
}
