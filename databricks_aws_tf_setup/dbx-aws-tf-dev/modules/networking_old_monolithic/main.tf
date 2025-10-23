# ============================================================================
# Databricks Networking Module - Enterprise-Grade Production Architecture
# ============================================================================
#
# PRODUCTION-READY DESIGN:
# ------------------------
# This configuration represents best practices for Databricks Premium tier
# in production environments. It provides high availability, security, and
# cost optimization through proper use of NAT Gateways + VPC Endpoints.
#
# ARCHITECTURE:
# -------------
# VPC (/24 for demo, typically /16 in production)
#   ├── Private Subnets (2x /26) ← All Databricks workloads
#   │   ├── NAT Gateway per AZ (high availability)
#   │   └── VPC Endpoints (reduce NAT data charges)
#   └── Public Subnets (2x /28) ← NAT Gateways only
#       └── Internet Gateway
#
# WHY THIS DESIGN:
# ----------------
# 1. NAT Gateway: Required for external integrations (APIs, Git, PyPI, etc.)
# 2. Multi-AZ NAT: Prevents single AZ failure from breaking internet access
# 3. VPC Endpoints: Bypass NAT for AWS services (cheaper, more secure)
# 4. No Databricks traffic in public subnets (defense in depth)
#
# ENTERPRISE TIER ENHANCEMENT:
# -----------------------------
# With Databricks Enterprise + AWS PrivateLink, you would replace the
# public/NAT/IGW setup with:
#   - PrivateLink Endpoint for Databricks Control Plane (no internet needed!)
#   - All traffic stays within AWS private network
#   - Enhanced security posture, meets strictest compliance requirements
#   - Similar cost to NAT Gateway, but zero internet exposure
#
# SECURITY LAYERS:
# ----------------
# 1. Network Isolation: Private subnets only, no public IPs on workloads
# 2. Security Groups: Restrict traffic at instance/ENI level
# 3. VPC Endpoints: AWS API traffic never leaves AWS backbone
# 4. NAT Gateway: Single controlled egress point for internet
# 5. (Future) NACLs: Additional subnet-level filtering if needed
#
# COST OPTIMIZATION:
# ------------------
# - NAT Gateway: ~$64/month (2 AZs) + $0.045/GB
# - VPC Endpoints: ~$14/month (STS + Kinesis) + $0.01/GB
# - S3 Gateway Endpoint: FREE
# - Total: ~$78/month base + data transfer
# - Savings: VPC Endpoints reduce NAT data charges by routing AWS traffic privately
#
# ============================================================================

# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "dev" {
  cidr_block                           = var.vpc_cidr_block
  enable_dns_support                   = true
  enable_dns_hostnames                 = true
  enable_network_address_usage_metrics = true
  assign_generated_ipv6_cidr_block     = false

  tags = {
    Name = "vpc-${var.project_name}-${var.env}"
  }
}

# VPC Flow Logs - Enterprise Security Requirement
# Captures IP traffic for security analysis, troubleshooting, and compliance
# Cost: CloudWatch Logs data ingestion charges (~$0.50/GB)
# In production, consider S3 destination for lower costs
resource "aws_flow_log" "vpc" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.dev.id

  tags = {
    Name = "flowlog-${var.project_name}-${var.env}"
  }
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flowlogs-${var.project_name}-${var.env}"
  retention_in_days = 7 # Reduce for cost savings in dev, use 30-90 days in production

  tags = {
    Name = "flowlogs-${var.project_name}-${var.env}"
  }
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_logs" {
  name = "vpc-flowlogs-${var.project_name}-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "vpc-flowlogs-role-${var.project_name}-${var.env}"
  }
}

# IAM Policy for VPC Flow Logs to write to CloudWatch
resource "aws_iam_role_policy" "flow_logs" {
  name = "vpc-flowlogs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Private subnets for Databricks (minimum 2 required in different AZs)
# Each subnet must be /26 or larger (minimum 64 IPs)
resource "aws_subnet" "private" {
  count                           = var.subnet_count
  vpc_id                          = aws_vpc.dev.id
  cidr_block                      = cidrsubnet(aws_vpc.dev.cidr_block, var.private_subnet_newbits, count.index)
  availability_zone               = data.aws_availability_zones.available.names[count.index]
  assign_ipv6_address_on_creation = false

  tags = {
    Name = "sn-pvt-${var.project_name}-${var.env}-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# Public subnets - only for NAT Gateways (can be smaller, /28 is sufficient)
resource "aws_subnet" "public" {
  count                           = var.subnet_count
  vpc_id                          = aws_vpc.dev.id
  cidr_block                      = cidrsubnet(aws_vpc.dev.cidr_block, var.public_subnet_newbits, count.index + 4)
  availability_zone               = data.aws_availability_zones.available.names[count.index]
  assign_ipv6_address_on_creation = false
  map_public_ip_on_launch         = true

  tags = {
    Name = "sn-pub-${var.project_name}-${var.env}-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# Internet Gateway for public subnets
# Note: Databricks workloads NEVER directly access this
# Only used by NAT Gateways to provide internet egress for private subnets
resource "aws_internet_gateway" "dev" {
  vpc_id = aws_vpc.dev.id

  tags = {
    Name = "igw-${var.project_name}-${var.env}"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = var.subnet_count
  domain = "vpc"

  tags = {
    Name = "eip-nat-${var.project_name}-${var.env}-${data.aws_availability_zones.available.names[count.index]}"
  }

  depends_on = [aws_internet_gateway.dev]
}

# NAT Gateways in public subnets (one per AZ for high availability)
# Provides internet egress for Databricks clusters in private subnets
# Cost: ~$32/month per NAT Gateway + $0.045/GB data processed
resource "aws_nat_gateway" "dev" {
  count         = var.subnet_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "nat-${var.project_name}-${var.env}-${data.aws_availability_zones.available.names[count.index]}"
  }

  depends_on = [aws_internet_gateway.dev]
}

# Public route table - shared by all public subnets
# Only routes to Internet Gateway (no Databricks workloads use this)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.dev.id

  tags = {
    Name = "rt-pub-${var.project_name}-${var.env}"
  }
}

# Public route to Internet Gateway
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.dev.id
}

# Private route tables (one per AZ for high availability)
# Each routes internet traffic through its own NAT Gateway
resource "aws_route_table" "private" {
  count  = var.subnet_count
  vpc_id = aws_vpc.dev.id

  tags = {
    Name = "rt-pvt-${var.project_name}-${var.env}-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# Private routes to NAT Gateways (one per AZ)
resource "aws_route" "private_nat" {
  count                  = var.subnet_count
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.dev[count.index].id
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = var.subnet_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with their respective private route tables
resource "aws_route_table_association" "private" {
  count          = var.subnet_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ============================================================================
# VPC Endpoints - Enterprise Best Practice
# ============================================================================
# VPC Endpoints provide private connectivity to AWS services without traversing
# the internet or NAT Gateway. This improves security and reduces data costs.
#
# REQUIRED for Databricks:
# - S3: Delta Lake, notebooks, libraries, logs
# - STS: AWS credential vending, cross-account access
# - Kinesis: Databricks internal communication (required!)
#
# OPTIONAL (adds ~$7/month each, but recommended for production):
# - EC2: For cluster creation/management (reduces NAT traffic)
# - Glue: If using AWS Glue Data Catalog with Databricks
# - SecretsManager: Secure credential management
#
# ENTERPRISE TIER ALTERNATIVE:
# With Databricks Enterprise tier, you would add:
# - Databricks PrivateLink Endpoint (replaces public control plane access)
# - Enables 100% private connectivity (no IGW/NAT needed at all)
# - Required for certain compliance frameworks (HIPAA, PCI-DSS strict mode)
#
# ============================================================================

# S3 Gateway Endpoint (FREE - always enable this!)
# Routes S3 API calls privately through AWS backbone
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.dev.id
  service_name      = "com.amazonaws.${data.aws_availability_zones.available.id}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = {
    Name = "vpce-s3-${var.project_name}-${var.env}"
  }
}

# STS Interface Endpoint (REQUIRED for Databricks)
# Used for IAM role assumption and credential vending
# Cost: ~$7.20/month + $0.01/GB data transfer
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.dev.id
  service_name        = "com.amazonaws.${data.aws_availability_zones.available.id}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-sts-${var.project_name}-${var.env}"
  }
}

# Kinesis Interface Endpoint (REQUIRED for Databricks)
# Used for internal Databricks control plane communication
# Cost: ~$7.20/month + $0.01/GB data transfer
resource "aws_vpc_endpoint" "kinesis" {
  vpc_id              = aws_vpc.dev.id
  service_name        = "com.amazonaws.${data.aws_availability_zones.available.id}.kinesis-streams"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-kinesis-${var.project_name}-${var.env}"
  }
}

# EC2 Interface Endpoint (RECOMMENDED for production)
# Reduces NAT Gateway usage for cluster management operations
# Cost: ~$7.20/month + $0.01/GB data transfer
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.dev.id
  service_name        = "com.amazonaws.${data.aws_availability_zones.available.id}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-ec2-${var.project_name}-${var.env}"
  }
}

# Security Group for VPC Endpoints
# Allows HTTPS traffic from private subnets only
resource "aws_security_group" "vpc_endpoints" {
  name        = "vpce-${var.project_name}-${var.env}"
  description = "Security group for VPC endpoints - allows HTTPS from Databricks subnets"
  vpc_id      = aws_vpc.dev.id

  ingress {
    description = "HTTPS from Databricks private subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = aws_subnet.private[*].cidr_block
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpce-sg-${var.project_name}-${var.env}"
  }
}
