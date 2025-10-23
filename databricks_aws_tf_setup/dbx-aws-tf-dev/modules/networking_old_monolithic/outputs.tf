output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.dev.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.dev.cidr_block
}

output "pvt_subnet_ids" {
  description = "List of private subnet IDs for Databricks"
  value       = aws_subnet.private[*].id
}

output "pvt_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

output "pvt_subnet_availability_zones" {
  description = "List of private subnet availability zones used"
  value       = aws_subnet.private[*].availability_zone
}

output "pub_subnet_ids" {
  description = "List of public subnet IDs for Databricks"
  value       = aws_subnet.public[*].id
}

output "pub_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "pub_subnet_availability_zones" {
  description = "List of public subnet availability zones used"
  value       = aws_subnet.public[*].availability_zone
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.dev.id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.dev[*].id
}

output "nat_gateway_public_ips" {
  description = "List of Elastic IPs attached to NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "public_route_table_id" {
  description = "The ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = aws_route_table.private[*].id
}
