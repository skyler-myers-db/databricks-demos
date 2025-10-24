/**
 * Databricks Cross-Account IAM Policy Module
 *
 * Purpose:
 * Grants Databricks the EC2 and IAM permissions needed to provision and manage
 * compute resources (clusters) in your AWS account.
 *
 * This is the "Step 2" policy from Databricks workspace credential setup:
 * "Customer-managed VPC with default restrictions"
 *
 * Permissions Granted:
 * - EC2: Launch instances, attach volumes, manage security groups, spot instances, fleets
 * - IAM: Create service-linked role for EC2 Spot
 *
 * Scope: Cross-account access for Databricks control plane to provision clusters
 *
 * Databricks Documentation:
 * https://docs.databricks.com/administration-guide/account-api/iam-role.html
 *
 * Cost: $0/month (IAM policies are free)
 */

# IAM policy document for Databricks cross-account compute access
data "aws_iam_policy_document" "databricks_cross_account_policy" {
  # Statement 1: EC2 permissions for cluster provisioning
  statement {
    sid    = "DatabricksEC2Access"
    effect = "Allow"
    actions = [
      # Instance management
      "ec2:AssociateIamInstanceProfile",
      "ec2:AttachVolume",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CancelSpotInstanceRequests",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteTags",
      "ec2:DeleteVolume",
      "ec2:DetachVolume",
      "ec2:DisassociateIamInstanceProfile",
      "ec2:ReplaceIamInstanceProfileAssociation",
      "ec2:RequestSpotInstances",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RunInstances",
      "ec2:TerminateInstances",

      # Describe/read operations
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

      # EC2 Fleet management (modern replacement for Spot Instances)
      "ec2:DescribeFleetHistory",
      "ec2:ModifyFleet",
      "ec2:DeleteFleets",
      "ec2:DescribeFleetInstances",
      "ec2:DescribeFleets",
      "ec2:CreateFleet",

      # Launch Template management
      "ec2:DeleteLaunchTemplate",
      "ec2:GetLaunchTemplateData",
      "ec2:CreateLaunchTemplate",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:ModifyLaunchTemplate",
      "ec2:DeleteLaunchTemplateVersions",
      "ec2:CreateLaunchTemplateVersion",

      # Network interface management
      "ec2:AssignPrivateIpAddresses",

      # Spot placement optimization
      "ec2:GetSpotPlacementScores"
    ]
    resources = ["*"]
  }

  # Statement 2: IAM permissions for EC2 Spot service-linked role
  statement {
    sid    = "DatabricksSpotServiceLinkedRole"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
      "iam:PutRolePolicy"
    ]
    resources = [
      "arn:aws:iam::*:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot"
    ]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["spot.amazonaws.com"]
    }
  }
}

# Create IAM policy from document
resource "aws_iam_policy" "databricks_cross_account_policy" {
  name        = var.policy_name
  description = "Grants Databricks cross-account access to provision EC2 instances and manage compute resources"
  path        = "/databricks/"
  policy      = data.aws_iam_policy_document.databricks_cross_account_policy.json

  tags = {
    Name                = var.policy_name
    Purpose             = "Databricks cross-account compute access"
    DatabricksWorkspace = var.workspace_name
    PolicyType          = "CrossAccountCompute"
  }
}

# Attach policy to Databricks IAM role
resource "aws_iam_role_policy_attachment" "databricks_cross_account_policy" {
  role       = var.role_name
  policy_arn = aws_iam_policy.databricks_cross_account_policy.arn
}

# Outputs
output "cross_account_policy_arn" {
  description = "ARN of the cross-account compute policy"
  value       = aws_iam_policy.databricks_cross_account_policy.arn
}

output "cross_account_policy_name" {
  description = "Name of the cross-account compute policy"
  value       = aws_iam_policy.databricks_cross_account_policy.name
}

output "cross_account_policy_id" {
  description = "Unique ID of the cross-account compute policy"
  value       = aws_iam_policy.databricks_cross_account_policy.id
}

output "cross_account_attachment_id" {
  description = "ID of the policy attachment to role"
  value       = aws_iam_role_policy_attachment.databricks_cross_account_policy.id
}

# Configuration status
output "configuration_status" {
  description = "Module configuration status and next steps"
  value = {
    step_completed = "Step 2: Cross-Account Compute Policy Attached"
    permissions_granted = {
      ec2_operations = [
        "Launch/terminate instances",
        "Manage volumes and attachments",
        "Configure security groups",
        "Spot instance management",
        "EC2 Fleet management",
        "Launch template management",
        "Network interface management"
      ]
      iam_operations = [
        "Create EC2 Spot service-linked role"
      ]
      resource_scope = "* (required for EC2 operations)"
    }
    role_attached   = var.role_name
    deployment_type = "Customer-managed VPC with default restrictions"
    next_step       = "Credential configuration already created in Step 4 (databricks_mws_credentials)"
    validation      = "Databricks validates during credential configuration creation"
  }
}

# Cost analysis
output "cost_estimate" {
  description = "Monthly cost estimate for cross-account policy"
  value = {
    policy_cost     = "$0.00/month (IAM policies are free)"
    attachment_cost = "$0.00/month (Policy attachments are free)"
    ec2_costs       = "Variable (EC2 instances billed based on cluster usage)"
    total_monthly   = "$0.00/month (policy only)"
    notes           = "IAM policies have no direct cost. EC2 instances for Databricks clusters are billed separately based on usage."
  }
}
