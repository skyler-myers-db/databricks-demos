/**
 * Databricks Network Configuration Module (Step 5)
 *
 * Purpose:
 * Registers customer-managed VPC, subnets, and security groups with Databricks account
 * for workspace creation in your own VPC (instead of Databricks-managed VPC).
 *
 * Prerequisites (must be completed):
 * - VPC created with proper CIDR sizing
 * - At least 2 subnets (private) across different AZs
 * - Security group(s) configured for Databricks workspace
 * - Network ACLs configured (if Premium tier)
 *
 * Important Constraints:
 * - Network configuration CANNOT be reused across workspaces (per Databricks docs)
 * - Each workspace needs its own network configuration object
 * - VPC and subnets CAN be shared, but size them appropriately for scale
 *
 * Databricks Requirements:
 * - Minimum 2 subnets in different AZs (for HA)
 * - Subnets must be private (no direct internet access)
 * - At least 1 security group
 * - VPC must meet Databricks networking requirements
 *
 * Databricks Documentation:
 * https://docs.databricks.com/administration-guide/cloud-configurations/aws/customer-managed-vpc.html
 *
 * Cost: $0/month (configuration metadata only, no infrastructure costs)
 */

# Databricks network configuration resource
resource "databricks_mws_networks" "this" {
  account_id         = var.databricks_account_id
  network_name       = var.network_configuration_name
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # Network configuration metadata
  # This tells Databricks account which VPC/subnets/SGs to use for workspace
  # IMPORTANT: Cannot be reused across workspaces (must create new config per workspace)
}

# Outputs
output "network_id" {
  description = "ID of the network configuration (use in workspace creation)"
  value       = databricks_mws_networks.this.network_id
}

output "network_name" {
  description = "Name of the network configuration"
  value       = databricks_mws_networks.this.network_name
}

output "vpc_id" {
  description = "VPC ID registered with Databricks"
  value       = databricks_mws_networks.this.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs registered with Databricks"
  value       = databricks_mws_networks.this.subnet_ids
}

output "security_group_ids" {
  description = "Security group IDs registered with Databricks"
  value       = databricks_mws_networks.this.security_group_ids
}

output "vpc_status" {
  description = "VPC validation status from Databricks"
  value       = databricks_mws_networks.this.vpc_status
}

# Configuration status
output "configuration_status" {
  description = "Module configuration status and next steps"
  value = {
    step_completed = "Step 5: Network Configuration Created"
    network_config = {
      id                   = databricks_mws_networks.this.network_id
      name                 = databricks_mws_networks.this.network_name
      vpc_id               = var.vpc_id
      subnet_count         = length(var.subnet_ids)
      security_group_count = length(var.security_group_ids)
      vpc_status           = databricks_mws_networks.this.vpc_status
    }
    account_id = var.databricks_account_id
    constraints = {
      reusability         = "CANNOT be reused across workspaces"
      vpc_sharing         = "VPC and subnets CAN be shared (ensure proper sizing)"
      min_subnets         = "2 subnets required (different AZs)"
      min_security_groups = "1 security group required"
    }
    next_step = "Step 6: Create Databricks workspace (combines storage + network configs)"
    required_info = {
      storage_configuration_id = "From databricks_storage_config module"
      credentials_id           = "From databricks_storage_config module"
      network_id               = databricks_mws_networks.this.network_id
      deployment_name          = "Unique workspace name"
      aws_region               = "AWS region for workspace"
    }
  }
}

# Validation warnings
output "validation_warnings" {
  description = "Important validation notes"
  value = {
    network_validation  = "Some validation errors only appear during workspace creation. Monitor workspace deployment for additional errors."
    vpc_sizing          = "If sharing VPC across workspaces, ensure CIDR is large enough for scale. Recommended: /16 VPC, /19 subnets per workspace."
    security_groups     = "Verify security group allows cluster-to-cluster communication (all TCP/UDP from same SG)."
    subnet_requirements = "Subnets must be private (no direct IGW route). NAT Gateway required for outbound access."
  }
}

# Cost analysis
output "cost_estimate" {
  description = "Monthly cost estimate for network configuration"
  value = {
    configuration_cost  = "$0.00/month (metadata only, no infrastructure)"
    infrastructure_cost = "See networking modules for VPC, subnets, NAT Gateway, VPC endpoints costs"
    total_monthly       = "$0.00/month (configuration metadata)"
    notes               = "Network configuration is free. Actual VPC infrastructure costs are in networking modules (~$99/month for NAT GW + VPC endpoints)."
  }
}
