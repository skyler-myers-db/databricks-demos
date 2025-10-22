output "vpc_id"                 { value = aws_vpc.this.id }
output "workspace_sg_id"        { value = aws_security_group.workspace.id }
output "vpce_sg_id"             { value = aws_security_group.vpce.id }
output "private_subnet_ids"     { value = [for s in aws_subnet.private : s.id] }
output "endpoint_subnet_ids"    { value = [for s in aws_subnet.endpoint : s.id] }
output "private_route_table_ids"{ value = [for rt in aws_route_table.private : rt.id] }
