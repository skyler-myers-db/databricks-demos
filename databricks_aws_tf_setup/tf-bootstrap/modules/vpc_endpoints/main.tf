# S3 Gateway endpoint (regional) for private subnets (data plane to S3)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids
  tags = merge(var.tags, { Name = "s3-gateway" })
}

# STS/Kinesis/RDS interface endpoints (recommended by Databricks)
locals {
  interface_services = [
    "sts", "kinesis-streams", "rds"
  ]
}

resource "aws_vpc_endpoint" "ifaces" {
  for_each           = toset(local.interface_services)
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type  = "Interface"
  private_dns_enabled = true
  subnet_ids         = var.subnet_ids
  security_group_ids = [var.sg_id]
  tags = merge(var.tags, { Name = "if-${each.key}" })
}

# ENTERPRISE-ONLY: Backend PrivateLink VPCEs (Relay + Workspace REST API).
# These must be registered in Databricks account, then referenced from network config
resource "aws_vpc_endpoint" "relay" {
  count              = var.enable_backend_pl && var.relay_service_name != null ? 1 : 0
  vpc_id             = var.vpc_id
  vpc_endpoint_type  = "Interface"
  # Use regional *Databricks* service name for SCC Relay from docs. Populate via variable in real use.
  service_name       = var.relay_service_name
  private_dns_enabled = false
  subnet_ids         = var.subnet_ids
  security_group_ids = [var.sg_id]
  tags = merge(var.tags, { Name = "databricks-relay" })
}

resource "aws_vpc_endpoint" "restapi" {
  count              = var.enable_backend_pl && var.workspace_service_name != null ? 1 : 0
  vpc_id             = var.vpc_id
  vpc_endpoint_type  = "Interface"
  # Use regional Workspace (including REST API) service name. Populate via variable in real use.
  service_name       = var.workspace_service_name
  private_dns_enabled = false
  subnet_ids         = var.subnet_ids
  security_group_ids = [var.sg_id]
  tags = merge(var.tags, { Name = "databricks-restapi" })
}

# Databricks provider MWS registrations require VPCE IDs.
# We expose the IDs so upstream module can register via databricks_mws_vpc_endpoint.
output "relay_vpce_id"   { value = try(aws_vpc_endpoint.relay[0].id, null) }
output "restapi_vpce_id" { value = try(aws_vpc_endpoint.restapi[0].id, null) }
output "s3_gw_vpce_ids"  { value = [aws_vpc_endpoint.s3.id] }

# Placeholders for MWS registrations (filled by databricks_account module)
