# AWS Account
data "aws_availability_zones" "available" {
  state                  = "available"
  all_availability_zones = false
}

data "aws_region" "current" {}
resource "aws_organizations_account" "this" {
  name                       = "acc-${var.project_name}-${data.aws_region.current.region}"
  email                      = var.aws_acc_email
  close_on_deletion          = true
  create_govcloud            = false
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = var.parent_ou_id
  role_name                  = var.aws_acc_switch_role

  lifecycle {
    prevent_destroy = false
  }
}

# AWS VPC
# https://docs.databricks.com/aws/en/security/network/classic/customer-managed-vpc#overview

resource "aws_vpc" "this" {
  cidr_block                           = var.vpc_cidr_block
  enable_dns_support                   = true
  enable_dns_hostnames                 = true
  enable_network_address_usage_metrics = true
  assign_generated_ipv6_cidr_block     = false
  instance_tenancy                     = "default"

  tags = {
    Name = "vpc-${var.project_name}-${data.aws_region.current.region}"
  }
}

# AWS Subnets/Route Tables
# https://docs.databricks.com/aws/en/security/network/classic/customer-managed-vpc#subnets

resource "aws_internet_gateway" "this" { # For non-PL only
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "igw-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "epi-ngw-${var.project_name}-${data.aws_region.current.region}"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 8, 2)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "subnet-public-${var.project_name}-${data.aws_region.current.region}-${data.aws_availability_zones.available.names[0]}"
  }
}

resource "aws_subnet" "private" {
  count  = 2
  vpc_id = aws_vpc.this.id
  cidr_block = cidrsubnet(
    var.vpc_cidr_block,
    8,
    count.index
  )
  availability_zone               = data.aws_availability_zones.available.names[count.index]
  assign_ipv6_address_on_creation = false

  tags = {
    Name = "subnet-private-${var.project_name}-${data.aws_region.current.region}-${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "ngw-${var.project_name}-${data.aws_region.current.region}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "rtb-public-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "rtb-private-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# AWS Security Groups
# https://docs.databricks.com/aws/en/security/network/classic/customer-managed-vpc#security-groups

resource "aws_security_group" "dbx_workspace" {
  name        = "dbx-workspace-sg-${var.project_name}-${data.aws_region.current.region}"
  description = "Secruity group for Databricks workspace clusters"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "dbx-workspace-sg-${var.project_name}-${data.aws_region.current.region}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "all_tcp" {
  security_group_id = aws_security_group.dbx_workspace.id
  description       = "Allow all TCP access to the workspace security group (for internal traffic)"

  referenced_security_group_id = aws_security_group.dbx_workspace.id
  ip_protocol                  = "tcp"
  from_port                    = 0
  to_port                      = 65535


  tags = {
    Name = "dbx-tcp-egress-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_vpc_security_group_egress_rule" "all_udp" {
  security_group_id = aws_security_group.dbx_workspace.id
  description       = "Allow all UDP access to the workspace security group (for internal traffic)"

  referenced_security_group_id = aws_security_group.dbx_workspace.id
  ip_protocol                  = "udp"
  from_port                    = 0
  to_port                      = 65535

  tags = {
    Name = "dbx-udp-egress-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_vpc_security_group_egress_rule" "tcp_443" {
  security_group_id = aws_security_group.dbx_workspace.id
  description       = "443: for Databricks infrastructure, cloud data sources, and library repositories"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  tags = {
    Name = "dbx_tcp_egress-443-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_vpc_security_group_egress_rule" "tcp_3306" {
  security_group_id = aws_security_group.dbx_workspace.id
  description       = "3306: for the metastore"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 3306
  to_port     = 3306

  tags = {
    Name = "dbx_tcp_egress-3306-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_vpc_security_group_egress_rule" "tcp_53" {
  security_group_id = aws_security_group.dbx_workspace.id
  description       = "53: for DNS resolution with custom DNS"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 53
  to_port     = 53

  tags = {
    Name = "dbx_tcp_egress-53-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_vpc_security_group_egress_rule" "tcp_6666" {
  security_group_id = aws_security_group.dbx_workspace.id
  description       = "6666: for secure cluster connectivity. This is only required for PrivateLink"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 6666
  to_port     = 6666

  tags = {
    Name = "dbx_tcp_egress-6666-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_vpc_security_group_egress_rule" "tcp_2443" {
  security_group_id = aws_security_group.dbx_workspace.id
  description       = "2443: Supports FIPS encryption. Only required with the compliance security profile."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 2443
  to_port     = 2443

  tags = {
    Name = "dbx_tcp_egress-2443-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_vpc_security_group_egress_rule" "tcp_8443" {
  security_group_id = aws_security_group.dbx_workspace.id
  description       = "8443: for internal calls from the Databricks compute plane to the Databricks control plane API."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 8443
  to_port     = 8443

  tags = {
    Name = "dbx_tcp_egress-8443-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_vpc_security_group_egress_rule" "tcp_8444" {
  security_group_id = aws_security_group.dbx_workspace.id
  description       = "8444: for Unity Catalog logging and lineage data streaming into Databricks."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 8444
  to_port     = 8444

  tags = {
    Name = "dbx_tcp_egress-8444-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_vpc_security_group_egress_rule" "tcp_future" {
  security_group_id = aws_security_group.dbx_workspace.id
  description       = "8445 through 8451: Future extendability."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 8445
  to_port     = 8451

  tags = {
    Name = "dbx_tcp_egress-future-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "all_tcp" {
  security_group_id = aws_security_group.dbx_workspace.id
  description       = "Allow TCP on all ports when traffic source uses the same security group"

  referenced_security_group_id = aws_security_group.dbx_workspace.id
  ip_protocol                  = "tcp"
  from_port                    = 0
  to_port                      = 65535


  tags = {
    Name = "dbx-tcp-ingress-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "all_udp" {
  security_group_id = aws_security_group.dbx_workspace.id
  description       = "Allow UDP on all ports when traffic source uses the same security group"

  referenced_security_group_id = aws_security_group.dbx_workspace.id
  ip_protocol                  = "udp"
  from_port                    = 0
  to_port                      = 65535

  tags = {
    Name = "dbx-udp-ingress-${var.project_name}-${data.aws_region.current.region}"
  }
}

# AWS Network ACLS
# https://docs.databricks.com/aws/en/security/network/classic/customer-managed-vpc#subnet-level-network-acls

resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.private[*].id

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr_block
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 3306
    to_port    = 3306
  }

  egress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 6666
    to_port    = 6666
  }

  egress {
    protocol   = "tcp"
    rule_no    = 140
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 8443
    to_port    = 8443
  }

  egress {
    protocol   = "tcp"
    rule_no    = 150
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 8444
    to_port    = 8444
  }

  egress {
    protocol   = "tcp"
    rule_no    = 160
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 8445
    to_port    = 8451
  }

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  tags = {
    Name = "nacl-private-${var.project_name}-${data.aws_region.current.region}"
    Type = "private"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Configure Regional Endpoints
# https://docs.databricks.com/aws/en/security/network/classic/customer-managed-vpc#recommended-configure-regional-endpoints

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id, aws_route_table.private.id]

  tags = {
    Name = "vpce-s3-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.dbx_workspace.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-sts-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_vpc_endpoint" "kinesis" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.kinesis-streams"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.dbx_workspace.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-kinesis-${var.project_name}-${data.aws_region.current.region}"
  }
}

# Databricks Network Configuration
# https://docs.databricks.com/aws/en/admin/account-settings-e2/networks#create-a-network-configuration

resource "databricks_mws_networks" "workspace" {
  provider           = databricks.mws
  account_id         = var.dbx_acc_id
  network_name       = "dbx-workspace-network-config-${var.project_name}-${data.aws_region.current.region}"
  vpc_id             = aws_vpc.this.id
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.dbx_workspace.id]
}

# Workspace Root Storage Bucket
# https://docs.databricks.com/aws/en/admin/workspace/create-uc-workspace#step-1-create-an-s3-bucket

resource "aws_s3_bucket" "dbx_workspace_root" {
  bucket        = "dbx-workspace-root-${var.project_name}-${data.aws_region.current.region}"
  force_destroy = true
  tags = {
    Name = "dbx-workspace-root-${var.project_name}-${data.aws_region.current.region}"
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_policy" "dbx_workspace_root_access" {
  bucket = aws_s3_bucket.dbx_workspace_root.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Grant Databricks Access",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::414351767826:root"
        },
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = ["arn:aws:s3:::${aws_s3_bucket.dbx_workspace_root.id}/*", "arn:aws:s3:::${aws_s3_bucket.dbx_workspace_root.id}"],
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/DatabricksAccountId" = [var.dbx_acc_id]
          }
        }
      },
      {
        Sid    = "Prevent DBFS from accessing Unity Catalog metastore",
        Effect = "Deny",
        Principal = {
          AWS = "arn:aws:iam::414351767826:root"
        },
        Action   = ["s3:*"],
        Resource = ["arn:aws:s3:::${aws_s3_bucket.dbx_workspace_root.id}/unity-catalog/*"]
      }
    ]
  })
}

# IAM Role With Custom Trust Policy
# https://docs.databricks.com/aws/en/admin/workspace/create-uc-workspace#step-2-create-an-iam-role-with-a-custom-trust-policy

resource "aws_iam_role" "dbx_workspace_s3_access" {
  name        = "dbx-workspace-s3_access-role-${var.project_name}-${data.aws_region.current.region}"
  description = "IAM role to allow Databricks workspace access to S3 bucket"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = [
            "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL",
            "arn:aws:iam::${aws_organizations_account.this.id}:root" # Have to change documentation to switch to root to avoid self-referencing resource
          ]
        },
        Action = "sts:AssumeRole",
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.dbx_acc_id
          }
        }
      }
    ]
  })

  tags = {
    Name = "dbx-workspace-s3_access-role-${var.project_name}-${data.aws_region.current.region}"
  }
}

# S3 IAM Policy
# https://docs.databricks.com/aws/en/admin/workspace/create-uc-workspace#step-3-create-an-iam-policy-to-grant-read-and-write-access

resource "aws_iam_policy" "dbx_workspace_root_s3_access" {
  name        = "dbx-workspace-root-s3_access-policy-${var.project_name}-${data.aws_region.current.region}"
  description = "IAM policy to allow Databricks workspace access to S3 bucket"
  path        = "/databricks/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
        Resource = "arn:aws:s3:::${aws_s3_bucket.dbx_workspace_root.id}/unity-catalog/*"
      },
      {
        Effect   = "Allow",
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"],
        Resource = "arn:aws:s3:::${aws_s3_bucket.dbx_workspace_root.id}"
      },
      # {
      #   Action = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey*"],
      #   Resource = ["arn:aws:kms:<KMS-KEY>"],
      #   Effect = "Allow"
      # },
      {
        Action   = ["sts:AssumeRole"],
        Resource = ["arn:aws:iam::${aws_organizations_account.this.id}:role/${aws_iam_role.dbx_workspace_s3_access.name}"],
        Effect   = "Allow"
      }
    ]
  })

  tags = {
    Name = "dbx-workspace-root-s3_access-policy-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_iam_policy" "dbx_file_events" {
  name        = "dbx-file-events-policy-${var.project_name}-${data.aws_region.current.region}"
  description = "The IAM policy grants Databricks permission to update a bucket's event notification configuration, create an SNS topic, create an SQS queue, and subscribe the SQS queue to the SNS topic. These are required resources for features that use file events"
  path        = "/databricks/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManagedFileEventsSetupStatement",
        Effect = "Allow",
        Action = [
          "s3:GetBucketNotification",
          "s3:PutBucketNotification",
          "sns:ListSubscriptionsByTopic",
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:CreateTopic",
          "sns:TagResource",
          "sns:Publish",
          "sns:Subscribe",
          "sqs:CreateQueue",
          "sqs:DeleteMessage",
          "sqs:ReceiveMessage",
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
          "sqs:SetQueueAttributes",
          "sqs:TagQueue",
          "sqs:ChangeMessageVisibility",
          "sqs:PurgeQueue"
        ],
        Resource = ["arn:aws:s3:::${aws_s3_bucket.dbx_workspace_root.id}", "arn:aws:sqs:*:*:*", "arn:aws:sns:*:*:*"]
      },
      {
        Sid      = "ManagedFileEventsListStatement",
        Effect   = "Allow",
        Action   = ["sqs:ListQueues", "sqs:ListQueueTags", "sns:ListTopics"],
        Resource = "*"
      },
      {
        Sid      = "ManagedFileEventsTeardownStatement",
        Effect   = "Allow",
        Action   = ["sns:Unsubscribe", "sns:DeleteTopic", "sqs:DeleteQueue"],
        Resource = ["arn:aws:sqs:*:*:*", "arn:aws:sns:*:*:*"]
      }
    ]
  })

  tags = {
    Name = "dbx-file-events-policy-${var.project_name}-${data.aws_region.current.region}"
  }
}

resource "aws_iam_role_policy_attachment" "dbx_workspace_root_s3_access" {
  role       = aws_iam_role.dbx_workspace_s3_access.name
  policy_arn = aws_iam_policy.dbx_workspace_root_s3_access.arn
}

resource "aws_iam_role_policy_attachment" "dbx_file_events" {
  role       = aws_iam_role.dbx_workspace_s3_access.name
  policy_arn = aws_iam_policy.dbx_file_events.arn
}

# Databricks Workspace Storage Configuration
# https://docs.databricks.com/aws/en/admin/workspace/create-uc-workspace#step-4-create-the-storage-configuration

resource "databricks_mws_storage_configurations" "dbx_workspace_root" {
  provider                   = databricks.mws
  account_id                 = var.dbx_acc_id
  storage_configuration_name = "dbx-workspace-root-storage-config-${var.project_name}-${data.aws_region.current.region}"
  bucket_name                = aws_s3_bucket.dbx_workspace_root.id
}

# Databricks Credential Configuration
# https://docs.databricks.com/aws/en/admin/workspace/create-uc-workspace#create-a-credential-configuration

resource "aws_iam_role" "dbx_cross_account" {
  name        = "dbx-cross-account-${var.project_name}-${data.aws_region.current.region}"
  path        = "/databricks/"
  description = "Gives Databricks access to launch compute resources in the AWS account"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.dbx_acc_id
          }
        }
      }
    ]
  })

  tags = {
    Name    = "dbx-cross-account-${var.project_name}-${data.aws_region.current.region}"
    Purpose = "Databricks cross-account access"
  }
}

# Databricks Access Policy
# https://docs.databricks.com/aws/en/admin/workspace/create-uc-workspace#step-2-create-an-access-policy

resource "aws_iam_role_policy" "dbx_access" {
  name = "dbx-access-${var.project_name}-${data.aws_region.current.region}"
  role = aws_iam_role.dbx_cross_account.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Stmt1403287045000",
        Effect = "Allow",
        Action = [
          "ec2:AssociateIamInstanceProfile",
          "ec2:AttachVolume",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CancelSpotInstanceRequests",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteTags",
          "ec2:DeleteVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeIamInstanceProfileAssociations",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstances",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribePrefixLists",
          "ec2:DescribeReservedInstancesOfferings",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotInstanceRequests",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeVpcs",
          "ec2:DetachVolume",
          "ec2:DisassociateIamInstanceProfile",
          "ec2:ReplaceIamInstanceProfileAssociation",
          "ec2:RequestSpotInstances",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeFleetHistory",
          "ec2:ModifyFleet",
          "ec2:DeleteFleets",
          "ec2:DescribeFleetInstances",
          "ec2:DescribeFleets",
          "ec2:CreateFleet",
          "ec2:DeleteLaunchTemplate",
          "ec2:GetLaunchTemplateData",
          "ec2:CreateLaunchTemplate",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:ModifyLaunchTemplate",
          "ec2:DeleteLaunchTemplateVersions",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:AssignPrivateIpAddresses",
          "ec2:GetSpotPlacementScores"
        ],
        "Resource" = ["*"]
      },
      {
        Effect   = "Allow",
        Action   = ["iam:CreateServiceLinkedRole", "iam:PutRolePolicy"],
        Resource = "arn:aws:iam::*:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot",
        Condition = {
          StringLike = {
            "iam:AWSServiceName" = "spot.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "databricks_mws_credentials" "dbx_launch_compute" {
  provider         = databricks.mws
  credentials_name = "dbx-launch-compute-credentials-${var.project_name}-${data.aws_region.current.region}"
  role_arn         = aws_iam_role.dbx_cross_account.arn
}

# Create Databricks Metastore

resource "databricks_metastore" "this" {
  provider                                          = databricks.mws
  name                                              = "metastore-${var.project_name}-${data.aws_region.current.region}"
  region                                            = data.aws_region.current.region
  owner                                             = "skyler@entrada.ai"
  force_destroy                                     = true
  delta_sharing_scope                               = "INTERNAL_AND_EXTERNAL"
  delta_sharing_recipient_token_lifetime_in_seconds = 0
  delta_sharing_organization_name                   = "entrada"
}

resource "databricks_mws_workspaces" "this" {
  provider       = databricks.mws
  account_id     = var.dbx_acc_id
  workspace_name = "ws-${var.project_name}-${data.aws_region.current.region}"
  aws_region     = data.aws_region.current.region

  credentials_id           = databricks_mws_credentials.dbx_launch_compute.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.dbx_workspace_root.storage_configuration_id
  network_id               = databricks_mws_networks.workspace.network_id

  custom_tags = {
    owner = "skyler@entrda.ai"
    env   = "dev"
  }
}

resource "databricks_metastore_assignment" "this" {
  provider     = databricks.mws
  metastore_id = databricks_metastore.this.id
  workspace_id = databricks_mws_workspaces.this.workspace_id

  lifecycle {
    prevent_destroy = false
  }
}

# Create SVP and Groups

resource "databricks_service_principal" "workspace" {
  provider                   = databricks.mws
  display_name               = "svp-ws-${var.project_name}"
  active                     = true
  disable_as_user_deletion   = true
  force_delete_home_dir      = true
  force_delete_repos         = true
  databricks_sql_access      = true
  allow_cluster_create       = true
  allow_instance_pool_create = true
}

resource "databricks_group" "data_eng" {
  provider     = databricks.mws
  display_name = "data_eng"
}

data "databricks_user" "skyler" {
  provider  = databricks.mws
  user_name = "skyler@entrada.ai"
}
resource "databricks_mws_permission_assignment" "skyler" { # These may take a few mins to work, as the metastore assignments is not immediate
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = data.databricks_user.skyler.id
  permissions  = ["ADMIN"]

  depends_on = [databricks_metastore_assignment.this]
}

resource "databricks_mws_permission_assignment" "data_eng" {
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = databricks_group.data_eng.id
  permissions  = ["USER"]

  depends_on = [databricks_metastore_assignment.this]
}

resource "databricks_mws_permission_assignment" "svp" {
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = databricks_service_principal.workspace.id
  permissions  = ["ADMIN"]

  depends_on = [databricks_metastore_assignment.this]
}
