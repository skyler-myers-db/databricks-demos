data "aws_availability_zones" "this" {}

locals {
  workspace_tcp_egress_rules = {
    https_control_plane = {
      from        = 443
      to          = 443
      description = "Databricks infrastructure, cloud data sources, and library repositories"
    }
    workspace_dns = {
      from        = 53
      to          = 53
      description = "DNS resolution for custom DNS"
    }
    workspace_ui = {
      from        = 8443
      to          = 8443
      description = "Internal calls from the Databricks compute plane to the Databricks control plane API"
    }
    workspace_uc = {
      from        = 8444
      to          = 8444
      description = "Unity Catalog logging and lineage data streaming into Databricks"
    }
    workspace_fips = {
      from        = 2443
      to          = 2443
      description = "Supports FIPS encryption. Only required if the compliance security profile is enabled"
    }
    privatelink_backend = {
      from        = 6666
      to          = 6666
      description = "PrivateLink backend"
    }
    metastore = {
      from        = 3306
      to          = 3306
      description = "For the metastore"
    }
    workspace_internal_range = {
      from        = 8445
      to          = 8451
      description = "Future extendability"
    }
  }

  workspace_udp_egress_rules = {
    dns = {
      port        = 53
      description = "DNS lookups"
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(var.tags, { Name = "${var.project_name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, { Name = "${var.project_name}-igw" })
}

# Public subnets + route to IGW
resource "aws_subnet" "public" {
  for_each                = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.this.names[each.key]
  tags = merge(var.tags, { Name = "${var.project_name}-public-${each.key}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.project_name}-public-rt" })
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# NAT in one public subnet (can be HA with 2 NATs if desired)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.project_name}-nat-eip" })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(var.tags, { Name = "${var.project_name}-nat" })
  depends_on    = [aws_internet_gateway.igw]
}

# Private subnets + route to NAT
resource "aws_subnet" "private" {
  for_each          = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.this.names[each.key]
  tags = merge(var.tags, { Name = "${var.project_name}-private-${each.key}" })
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.project_name}-private-rt-${each.key}" })
}

resource "aws_route" "private_nat" {
  for_each                 = aws_route_table.private
  route_table_id           = each.value.id
  destination_cidr_block   = "0.0.0.0/0"
  nat_gateway_id           = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# (Optional) Endpoint subnets for VPCEs
resource "aws_subnet" "endpoint" {
  for_each          = { for idx, cidr in var.endpoint_subnet_cidrs : idx => cidr }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.this.names[each.key]
  tags = merge(var.tags, { Name = "${var.project_name}-endpoint-${each.key}" })
}

# Workspace SG (intra-traffic + egress rules required by Databricks)
resource "aws_security_group" "workspace" {
  name        = "${var.project_name}-ws-sg"
  description = "Databricks workspace SG"
  vpc_id      = aws_vpc.this.id

  # Ingress: allow self (TCP/UDP all)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "intra-SG"
  }

  # Egress: allow the specific Databricks control plane ports only
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
    description = "intra-SG TCP"
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    self        = true
    description = "intra-SG UDP"
  }

  dynamic "egress" {
    iterator = tcp_rule
    for_each = local.workspace_tcp_egress_rules
    content {
      description = tcp_rule.value.description
      from_port   = tcp_rule.value.from
      to_port     = coalesce(tcp_rule.value.to, tcp_rule.value.from)
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # dynamic "egress" {
  #   iterator = udp_rule
  #   for_each = local.workspace_udp_egress_rules
  #   content {
  #     description = udp_rule.value.description
  #     from_port   = udp_rule.value.port
  #     to_port     = udp_rule.value.port
  #     protocol    = "udp"
  #     cidr_blocks = ["0.0.0.0/0"]
  #   }
  # }

  tags = merge(var.tags, { Name = "${var.project_name}-ws-sg" })
}

# VPCE SG for interface endpoints
resource "aws_security_group" "vpce" {
  name        = "${var.project_name}-vpce-sg"
  description = "VPCE SG"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project_name}-vpce-sg" })
}
