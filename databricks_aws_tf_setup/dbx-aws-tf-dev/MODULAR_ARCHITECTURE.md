# Modular Networking Architecture - October 2025

## Overview

This Terraform project uses a **modular networking architecture** following modern AWS and Terraform best practices. The project has been split into **7 specialized modules**, each handling a specific AWS resource type with clear boundaries and dependencies.

## Architecture Benefits

### ✅ **Single Responsibility Principle**
Each module manages one specific AWS resource type, making code easier to understand, test, and maintain.

### ✅ **Explicit Dependencies**
Clear dependency chains ensure resources are created in the correct order without race conditions.

### ✅ **Reusability**
Modules can be versioned independently and reused across different environments and projects.

### ✅ **Easier Testing**
Smaller modules are easier to unit test and validate in isolation.

### ✅ **Better Collaboration**
Teams can work on different modules simultaneously without conflicts.

### ✅ **Cost Transparency**
Each module includes cost estimates and optimization notes inline.

## Module Structure

```
modules/
├── aws_account/                    # AWS Organizations account management
├── aws_vpc/                        # Core VPC with flow logs & DNS
├── aws_subnets/                    # Private & public subnet management
├── aws_internet_gateway/           # Internet Gateway (IGW)
├── aws_nat_gateway/                # NAT Gateways with EIPs (HA)
├── aws_route_tables/               # Route tables & associations
├── aws_security_groups/            # Security groups for endpoints
├── aws_vpc_endpoints/              # VPC Endpoints (S3, STS, Kinesis, EC2)
├── workspaces/                     # Databricks workspace creation
└── networking_old_monolithic/      # Archived legacy module (for reference)
```

## Dependency Flow

```
aws_vpc (foundation)
  ├── aws_subnets (requires VPC ID)
  ├── aws_internet_gateway (requires VPC ID)
  └── aws_security_groups (requires VPC ID, subnet CIDRs)
      ├── aws_nat_gateway (requires IGW, public subnets)
      ├── aws_route_tables (requires IGW, NAT GW, subnets)
      └── aws_vpc_endpoints (requires subnets, route tables, security groups)
```

## Module Details

### 1. **aws_vpc** - Core VPC Foundation
- **Purpose**: Creates VPC with DNS, flow logs, and monitoring
- **Resources**: VPC, CloudWatch Log Group, IAM roles for flow logs
- **Features**:
  - Network address usage metrics (AWS IPAM)
  - VPC Flow Logs to CloudWatch
  - Modern log class support (INFREQUENT_ACCESS for dev)
- **Cost**: Flow logs ~$0.50/GB ingestion (CloudWatch)

### 2. **aws_subnets** - Network Segmentation
- **Purpose**: Creates private and public subnets across AZs
- **Resources**: Private subnets (Databricks), public subnets (NAT GW only)
- **Features**:
  - Minimum /26 subnets (Databricks requirement)
  - Multi-AZ deployment (HA)
  - Deterministic CIDR calculations
- **Cost**: Free (subnets have no charges)

### 3. **aws_internet_gateway** - Public Internet Access
- **Purpose**: Provides internet connectivity for public subnets
- **Resources**: Single Internet Gateway (regional, HA)
- **Features**:
  - Automatic redundancy (AWS managed)
  - 99.99% availability SLA
- **Cost**: Free (IGW itself), data transfer charges apply

### 4. **aws_nat_gateway** - Secure Internet Egress
- **Purpose**: Provides outbound internet access for private subnets
- **Resources**: NAT Gateways (one per AZ), Elastic IPs
- **Features**:
  - Multi-AZ high availability
  - Managed service (no patching)
  - 55,000 connections per NAT GW
- **Cost**: ~$32/month per NAT GW + $0.045/GB data

### 5. **aws_route_tables** - Traffic Routing
- **Purpose**: Controls network traffic flow
- **Resources**: Public route table (shared), private route tables (per AZ)
- **Features**:
  - Same-AZ routing (no cross-AZ charges)
  - Automatic VPC endpoint routes
  - Support for future VPN/Transit Gateway
- **Cost**: Free (route tables have no charges)

### 6. **aws_security_groups** - Network Access Control
- **Purpose**: Firewall rules for VPC endpoints
- **Resources**: Security group for interface endpoints
- **Features**:
  - Least privilege access (HTTPS only)
  - Stateful firewall
  - Modern SG rules API (5.x provider)
- **Cost**: Free (security groups have no charges)

### 7. **aws_vpc_endpoints** - Private AWS Service Connectivity
- **Purpose**: Private connectivity to AWS services
- **Resources**: S3 (gateway), STS, Kinesis, EC2 (interface)
- **Features**:
  - Gateway endpoints: Free
  - Interface endpoints: Multi-AZ ENIs
  - Private DNS enabled (transparent)
- **Cost**:
  - S3 Gateway: **FREE**
  - Interface endpoints: ~$7.20/month per endpoint per AZ + $0.01/GB

## Databricks Requirements (Premium Tier)

### **Required Endpoints**:
1. ✅ **S3 (Gateway)** - Delta Lake, notebooks, cluster logs
2. ✅ **STS (Interface)** - IAM role assumption
3. ✅ **Kinesis (Interface)** - Control plane communication

### **Recommended**:
4. ✅ **EC2 (Interface)** - Reduces NAT costs for cluster management

### **Optional** (enable as needed):
- Glue - If using Glue Data Catalog
- Secrets Manager - Secure credential storage
- KMS - Customer-managed encryption keys
- CloudWatch Logs - Custom logging

## Enterprise Tier Considerations

### **With Databricks Enterprise + AWS PrivateLink**:

#### **No Changes Needed**:
- All 7 networking modules remain the same
- VPC, subnets, route tables, security groups unchanged

#### **Optional Enhancements**:
- **Can eliminate**: NAT Gateway + IGW (saves ~$64/month)
- **Add**: Databricks PrivateLink endpoint (~$14/month for 2 AZs)
- **Result**: Zero internet exposure, fully air-gapped

#### **PrivateLink Notes in Code**:
Every module includes detailed comments about Enterprise tier differences:
- When NAT Gateway becomes optional
- How PrivateLink affects routing
- Security group changes needed
- Cost comparisons Premium vs Enterprise

## Cost Breakdown (2 AZ Deployment)

### **Base Infrastructure**:
| Resource         | Monthly Cost | Notes                          |
| ---------------- | ------------ | ------------------------------ |
| VPC              | Free         | -                              |
| Flow Logs        | ~$3-5        | CloudWatch data ingestion      |
| Subnets          | Free         | -                              |
| Internet Gateway | Free         | Data transfer charges separate |
| NAT Gateways (2) | ~$64         | $32/month each + data          |
| Route Tables     | Free         | -                              |
| Security Groups  | Free         | -                              |

### **VPC Endpoints**:
| Endpoint | Type      | Monthly Cost    |
| -------- | --------- | --------------- |
| S3       | Gateway   | **FREE**        |
| STS      | Interface | ~$14.40 (2 AZs) |
| Kinesis  | Interface | ~$14.40 (2 AZs) |
| EC2      | Interface | ~$14.40 (2 AZs) |

### **Total Estimated Cost**:
- **Base**: ~$70/month
- **Endpoints**: ~$43/month
- **Grand Total**: ~**$113/month** (excluding data transfer)

### **Savings**:
- VPC Endpoints save ~$0.035/GB vs NAT Gateway for AWS services
- Typical savings: $20-50/month depending on usage

## Migration from Old Module

The old monolithic `networking` module has been archived to `networking_old_monolithic/` for reference.

### **What Changed**:
- ✅ Outputs remain compatible (same names)
- ✅ Resources have same tags (tracking preserved)
- ✅ CIDR calculations identical (no IP changes)
- ✅ All functionality preserved

### **Terraform State**:
⚠️ **IMPORTANT**: This is a **structural refactoring**, not an in-place migration.

**Options**:
1. **New Environment**: Deploy fresh with new modules (recommended)
2. **State Migration**: Use `terraform state mv` to migrate existing resources
3. **Recreate**: Destroy old, create new (requires downtime)

## Usage

### **Basic Configuration** (terraform.tfvars):
```hcl
# Networking configuration
vpc_cidr_block         = "10.0.0.0/24"  # Use /16-/20 for production
subnet_count           = 2               # Minimum 2 for HA
private_subnet_newbits = 2               # /26 subnets (64 IPs each)
public_subnet_newbits  = 4               # /28 subnets (16 IPs each)

# Project configuration
project_name = "dbx-tf"
env          = "-dev"
aws_region   = "us-east-2"
```

### **Apply**:
```bash
terraform init
terraform plan
terraform apply
```

### **Enable Optional Endpoints**:
Edit `main.tf` in the `vpc_endpoints` module call:
```hcl
module "vpc_endpoints" {
  # ...
  enable_glue_endpoint              = true  # Enable Glue
  enable_secrets_manager_endpoint   = true  # Enable Secrets Manager
  enable_kms_endpoint               = true  # Enable KMS
  enable_cloudwatch_logs_endpoint   = true  # Enable CloudWatch Logs
}
```

## Validation

### **Check Resources Created**:
```bash
# VPC and subnets
terraform state list | grep aws_vpc
terraform state list | grep aws_subnet

# NAT Gateways
terraform state list | grep aws_nat_gateway

# VPC Endpoints
terraform state list | grep aws_vpc_endpoint
```

### **Verify Connectivity**:
```bash
# Check VPC Flow Logs are active
aws ec2 describe-flow-logs --region us-east-2

# Check VPC Endpoints are available
aws ec2 describe-vpc-endpoints --region us-east-2
```

### **Cost Monitoring**:
```bash
# Check NAT Gateway costs
aws ce get-cost-and-usage \
  --time-period Start=2025-10-01,End=2025-10-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://nat-gateway-filter.json
```

## Best Practices

### **Production Recommendations**:
1. ✅ Use **2+ availability zones** (always)
2. ✅ Use **/16 to /20 VPC CIDR** (not /24)
3. ✅ Enable **VPC Flow Logs** (security requirement)
4. ✅ Use **30-90 day retention** for flow logs
5. ✅ Enable **EC2 endpoint** (cost savings)
6. ✅ Monitor **NAT Gateway metrics** (CloudWatch)
7. ✅ Set up **billing alerts** (Cost Explorer)

### **Security Recommendations**:
1. ✅ No public IPs on Databricks resources
2. ✅ Security groups use least privilege
3. ✅ VPC endpoint policies (optional, add if needed)
4. ✅ Flow logs sent to secure S3 bucket (prod)
5. ✅ Enable CloudTrail for API audit logs

### **Cost Optimization**:
1. ✅ Use VPC Endpoints for all AWS services
2. ✅ Cache packages in S3/CodeArtifact
3. ✅ Monitor NAT Gateway data transfer
4. ✅ Consider single NAT for dev (not prod)
5. ✅ Use S3 Gateway endpoint (always free)

## Troubleshooting

### **Common Issues**:

**Issue**: `Error creating VPC endpoint: InvalidParameter`
- **Solution**: Ensure security groups allow HTTPS (443) from private subnets

**Issue**: `NAT Gateway creation failed`
- **Solution**: Verify Internet Gateway exists first (dependency)

**Issue**: `Route table association conflict`
- **Solution**: Check for existing associations, use `terraform state rm` if needed

**Issue**: `Subnet CIDR too small for Databricks`
- **Solution**: Use minimum /26 subnets (64 IPs), adjust `private_subnet_newbits`

## Support & Documentation

### **AWS Documentation**:
- [VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [NAT Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)

### **Databricks Documentation**:
- [AWS Networking Requirements](https://docs.databricks.com/administration-guide/cloud-configurations/aws/customer-managed-vpc.html)
- [PrivateLink Setup](https://docs.databricks.com/administration-guide/cloud-configurations/aws/privatelink.html)

### **Terraform AWS Provider**:
- [AWS Provider 5.70+](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Changelog

### **October 2025 - Modular Refactoring**
- ✅ Split monolithic `networking` module into 7 specialized modules
- ✅ Added comprehensive inline documentation
- ✅ Included cost estimates for all resources
- ✅ Added Enterprise tier PrivateLink notes throughout
- ✅ Modern Terraform 1.9+ features (validation, timeouts)
- ✅ AWS Provider 5.70+ features (security group rules API)
- ✅ High availability by default (multi-AZ)
- ✅ Security best practices (flow logs, least privilege)

## License

This project follows the same license as the parent repository.

---

**Created**: October 2025
**Terraform Version**: >= 1.9.0
**AWS Provider Version**: >= 5.70
**Databricks Tier**: Premium (with Enterprise upgrade path)
