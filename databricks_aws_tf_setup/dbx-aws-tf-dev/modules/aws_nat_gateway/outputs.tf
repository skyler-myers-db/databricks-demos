output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs (one per AZ)"
  value       = aws_nat_gateway.this[*].id
}

output "nat_gateway_allocation_ids" {
  description = "List of Elastic IP allocation IDs associated with NAT Gateways"
  value       = aws_nat_gateway.this[*].allocation_id
}

output "nat_gateway_network_interface_ids" {
  description = "List of ENI IDs created by NAT Gateways"
  value       = aws_nat_gateway.this[*].network_interface_id
}

output "nat_gateway_private_ips" {
  description = "List of private IP addresses assigned to NAT Gateways"
  value       = aws_nat_gateway.this[*].private_ip
}

output "nat_gateway_public_ips" {
  description = "List of public IP addresses (Elastic IPs) for NAT Gateways. Whitelist these with external services."
  value       = aws_eip.nat[*].public_ip
}

output "nat_gateway_subnet_ids" {
  description = "List of public subnet IDs where NAT Gateways are placed"
  value       = aws_nat_gateway.this[*].subnet_id
}

output "elastic_ip_ids" {
  description = "List of Elastic IP IDs for NAT Gateways"
  value       = aws_eip.nat[*].id
}

output "elastic_ip_allocation_ids" {
  description = "List of Elastic IP allocation IDs"
  value       = aws_eip.nat[*].allocation_id
}

# Convenience output for cost monitoring
output "estimated_monthly_cost" {
  description = "Estimated base monthly cost for NAT Gateways (excludes data transfer). Multiply NAT count by ~$32/month."
  value       = "Base cost: ~$${var.subnet_count * 32}/month + data transfer charges (~$0.045/GB)"
}

# Map of AZ to NAT Gateway ID for easy lookup
output "nat_gateway_by_az" {
  description = "Map of availability zone to NAT Gateway ID"
  value = zipmap(
    var.availability_zones,
    aws_nat_gateway.this[*].id
  )
}

# Map of AZ to public IP for easy whitelisting
output "nat_public_ip_by_az" {
  description = "Map of availability zone to NAT Gateway public IP (for external service whitelisting)"
  value = zipmap(
    var.availability_zones,
    aws_eip.nat[*].public_ip
  )
}
