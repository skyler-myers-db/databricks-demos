# Databricks AWS Terraform Setup

Production-ready **Databricks workspace** deployment on AWS Premium tier with modern best practices.

## 🚀 Quick Start

```bash
# 1. Set up credentials
export AWS_ACCESS_KEY_ID="your-aws-key"
export AWS_SECRET_ACCESS_KEY="your-aws-secret"
export TF_VAR_dbx_acc_client_id="databricks-service-principal-id"
export TF_VAR_dbx_acc_client_secret="databricks-service-principal-secret"
export TF_VAR_dbx_account_id="databricks-account-uuid"

# 2. Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 3. Deploy infrastructure
terraform init
terraform plan
terraform apply

# 4. Access workspace
terraform output workspace_url
# Open URL and login with account admin credentials
```

## 📋 What Gets Deployed

### Infrastructure (17 Modules)

**Networking (9 modules)**
- VPC with DNS resolution and flow logs
- Private subnets (/26, Databricks minimum) across multiple AZs
- Public subnets (/28) for NAT Gateways only
- Internet Gateway for public subnet egress
- NAT Gateways (one per AZ for high availability)
- Route tables (private → NAT, public → IGW)
- Security Groups (intra-cluster + HTTPS egress)
- VPC Endpoints (S3 + STS gateway endpoints)
- Network ACLs (defense-in-depth stateless filtering)

**Storage & IAM (4 modules)**
- S3 root bucket (SSE-S3 encrypted, versioned)
- IAM role with External ID (confused deputy prevention)
- IAM storage policy (S3, KMS, STS, file events)
- IAM compute policy (52 EC2 actions, Spot permissions)

**Databricks Account (2 modules)**
- Storage configuration (MWS credentials + storage)
- Network configuration (VPC registration)

**Data Governance (1 module)**
- Unity Catalog metastore (NO storage_root, modern best practice)

**Workspace (1 module)**
- Databricks E2 workspace (Premium tier, Unity Catalog enabled)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│      DATABRICKS CONTROL PLANE               │
│   (Databricks-Managed AWS Account)          │
│   - Web UI, Notebooks, SQL Editor           │
│   - Unity Catalog Metadata ($0 cost)        │
└──────────────────┬──────────────────────────┘
                   │ Cross-Account IAM
                   │ (External ID Security)
┌──────────────────▼──────────────────────────┐
│      YOUR AWS ACCOUNT (Customer VPC)        │
├─────────────────────────────────────────────┤
│  VPC: 10.0.0.0/24 (customizable)            │
│  ├─ Private Subnets: 2× /26 (Databricks)   │
│  ├─ Public Subnets: 2× /28 (NAT GW only)   │
│  ├─ NAT Gateways: High availability         │
│  ├─ Security Groups: Zero-trust egress      │
│  └─ VPC Endpoints: S3 + STS (cost savings)  │
│                                              │
│  S3 Root Bucket:                            │
│  ├─ Cluster logs, notebooks, libraries      │
│  ├─ SSE-S3 encryption (AES-256)            │
│  └─ Versioning enabled                      │
│                                              │
│  Unity Catalog:                             │
│  ├─ Regional metastore (no storage root)    │
│  ├─ Catalog-level managed locations         │
│  └─ Managed tables (optimized features)     │
└─────────────────────────────────────────────┘
```

## 📊 Key Features

### Security
- ✅ **External ID** prevents confused deputy attacks
- ✅ **Zero-trust networking** (private subnets only)
- ✅ **Defense-in-depth** (Security Groups + NACLs)
- ✅ **Encryption at rest** (SSE-S3, KMS optional)
- ✅ **Least-privilege IAM** policies

### High Availability
- ✅ **Multi-AZ deployment** (minimum 2 AZs)
- ✅ **NAT Gateway per AZ** (fault tolerance)
- ✅ **Subnet redundancy** (automatic failover)

### Cost Optimization
- ✅ **VPC Endpoints** (avoid NAT Gateway charges for S3/STS)
- ✅ **Auto-termination** (configurable idle timeout)
- ✅ **Spot instances** support (60-90% savings)
- ✅ **S3 Bucket Keys** (reduce KMS costs if using KMS)

### Modern Best Practices
- ✅ **Unity Catalog** without storage_root
- ✅ **Catalog-level managed locations** (not metastore-level)
- ✅ **Managed tables** recommended (NOT external)
- ✅ **Modular architecture** (17 independent modules)
- ✅ **Terraform 1.13+** compatible
- ✅ **AWS Provider 6.17.0** (latest stable)
- ✅ **Databricks Provider 1.94.0** (Oct 2024 features)

## 💰 Cost Estimate

### Fixed Monthly Costs
| Component     | Quantity | Unit Cost   | Monthly         |
| ------------- | -------- | ----------- | --------------- |
| NAT Gateway   | 2        | $0.045/hour | $65             |
| NAT Transfer  | Variable | $0.045/GB   | ~$20            |
| VPC Endpoints | 2        | $0.01/hour  | $14             |
| S3 Storage    | Variable | $0.023/GB   | ~$23/TB         |
| **Subtotal**  |          |             | **~$100/month** |

### Variable Databricks Costs (DBU-based)
| Workload     | DBU Rate  | Example Usage    | Monthly        |
| ------------ | --------- | ---------------- | -------------- |
| Jobs Compute | $0.15/DBU | 100 hrs × 2 DBUs | $30            |
| All-Purpose  | $0.55/DBU | 40 hrs × 2 DBUs  | $44            |
| SQL Compute  | $0.22/DBU | 80 hrs × 1 DBU   | $18            |
| **Subtotal** |           |                  | **~$92/month** |

**Total Estimate**: ~**$192/month** for moderate usage

### Cost Reduction Tips
1. Enable auto-termination (15-30 minutes)
2. Use Spot instances for fault-tolerant workloads
3. Set cluster policies (restrict instance types)
4. Monitor DBU usage in billing dashboard
5. Use VPC endpoints (included above, saves NAT costs)

## 📁 Project Structure

```
.
├── main.tf                         # Root module (16 deployment steps)
├── variables.tf                    # Input variables with validation
├── outputs.tf                      # Infrastructure outputs
├── providers.tf                    # AWS + Databricks provider config
├── versions.tf                     # Terraform version constraints
├── terraform.tfvars                # User-specific values (gitignored)
│
├── ARCHITECTURE.md                 # Detailed architecture documentation
├── CROSS_ACCOUNT_SETUP.md          # IAM cross-account trust guide
├── DEPLOYMENT_STEPS.md             # Step-by-step deployment guide
├── COMPLETE_SETUP_SUMMARY.md       # Comprehensive reference
└── README.md                       # This file
│
└── modules/                        # 17 independent modules
    ├── aws_vpc/                    # VPC with DNS and flow logs
    ├── aws_subnets/                # Multi-AZ private/public subnets
    ├── aws_internet_gateway/       # Internet access for public subnets
    ├── aws_nat_gateway/            # NAT for private subnet egress
    ├── aws_route_tables/           # Routing configuration
    ├── aws_security_groups/        # Network security rules
    ├── aws_vpc_endpoints/          # S3/STS gateway endpoints
    ├── aws_network_acls/           # Stateless filtering
    ├── aws_account/                # AWS account creation (optional)
    ├── databricks_s3_root_bucket/  # Root storage bucket
    ├── databricks_iam_role/        # Cross-account IAM role
    ├── databricks_iam_policy/      # Storage permissions
    ├── databricks_cross_account_policy/ # Compute permissions (52 EC2 actions)
    ├── databricks_storage_config/  # MWS storage + credentials
    ├── databricks_network_config/  # MWS network registration
    ├── databricks_metastore/       # Unity Catalog metastore
    └── databricks_workspace/       # Workspace creation
```

## 🔧 Prerequisites

### Required Tools
- **Terraform**: >= 1.13.4
- **AWS CLI**: >= 2.0 (for credential management)
- **Git**: For version control

### Required Credentials

#### AWS Credentials
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-2"  # Optional
```

Or configure via `~/.aws/credentials`:
```ini
[default]
aws_access_key_id = your-access-key
aws_secret_access_key = your-secret-key
```

#### Databricks Credentials
1. **Create Service Principal** (Account Console → User Management → Service Principals)
2. **Assign Account Admin** role
3. **Generate OAuth Secret**
4. **Export credentials**:
```bash
export TF_VAR_dbx_account_id="12345678-1234-1234-1234-123456789012"
export TF_VAR_dbx_acc_client_id="service-principal-id"
export TF_VAR_dbx_acc_client_secret="service-principal-secret"
```

## 📝 Configuration

### terraform.tfvars Example
```hcl
# AWS Configuration
aws_region           = "us-east-2"
project_name         = "dbx-tf"
env                  = "-dev"

# Databricks Account
dbx_account_id              = "12345678-1234-1234-1234-123456789012"
dbx_metastore_owner_email   = "admin@company.com"  # Must be account admin

# Networking
vpc_cidr_block              = "10.0.0.0/24"  # 256 IPs (demo size)
subnet_count                = 2              # Number of AZs
private_subnet_newbits      = 2              # /26 subnets (64 IPs, Databricks min)
public_subnet_newbits       = 4              # /28 subnets (16 IPs, NAT GW only)

# Tags
aws_tags = {
  Project     = "Databricks-TF"
  Environment = "Development"
  ManagedBy   = "Terraform"
  CostCenter  = "Engineering"
}
```

### Production Adjustments
```hcl
# Larger VPC for production
vpc_cidr_block         = "10.0.0.0/20"  # 4,096 IPs
private_subnet_newbits = 3              # /23 subnets (512 IPs per AZ)
public_subnet_newbits  = 6              # /26 subnets (64 IPs per AZ)
subnet_count           = 3              # 3 AZs for higher availability

# Production environment
env = "-prod"
```

## 🚀 Deployment

### Step 1: Initialize Terraform
```bash
terraform init -upgrade
# Downloads providers and modules
# Takes ~30 seconds
```

### Step 2: Validate Configuration
```bash
terraform validate
# Checks syntax and configuration
# Takes ~5 seconds
```

### Step 3: Plan Deployment
```bash
terraform plan -out=tfplan
# Shows what will be created
# Review carefully before applying
# Takes ~30 seconds
```

### Step 4: Apply Infrastructure
```bash
terraform apply tfplan
# Creates all 17 modules
# Takes ~15-20 minutes total:
#   - Networking: 5 minutes
#   - Storage/IAM: 2 minutes
#   - Databricks configs: 3 minutes
#   - Metastore: 1 minute
#   - Workspace: 8-12 minutes
```

### Step 5: Access Workspace
```bash
# Get workspace URL
terraform output workspace_url
# Output: https://dbx-tf-dev-us-east-2.cloud.databricks.com

# Get workspace ID
terraform output workspace_id
# Output: 1234567890123456

# Get all outputs
terraform output
```

## 🔍 Post-Deployment

### 1. Initial Login
```
URL: <terraform output workspace_url>
Credentials: Account admin (SSO or username/password)
First login: 2-3 minutes for workspace initialization
```

### 2. Create Unity Catalog Structure
```sql
-- Create main catalog with managed location
CREATE CATALOG main
MANAGED LOCATION 's3://<your-root-bucket>/catalogs/main/';

-- Create schemas (Bronze/Silver/Gold medallion architecture)
CREATE SCHEMA main.bronze COMMENT 'Raw ingested data';
CREATE SCHEMA main.silver COMMENT 'Cleaned and validated data';
CREATE SCHEMA main.gold COMMENT 'Business-level aggregates';

-- Grant permissions
GRANT USE CATALOG ON main TO `account users`;
GRANT USE SCHEMA ON ALL SCHEMAS IN CATALOG main TO `account users`;

-- Create development catalog
CREATE CATALOG dev
MANAGED LOCATION 's3://<your-root-bucket>/catalogs/dev/';
```

### 3. Create First Cluster
```
Compute → Create Cluster:
- Name: analytics-cluster
- Runtime: 14.3.x LTS (latest)
- Node: m5.xlarge
- Workers: Min 1, Max 8 (autoscaling)
- Auto-termination: 30 minutes
- Mode: Single User (or Shared for Premium)
```

### 4. Run First Query
```sql
-- Verify Unity Catalog
SELECT current_catalog(), current_schema(), current_user();

-- Create sample table
CREATE TABLE main.bronze.sample AS
SELECT * FROM VALUES
  (1, 'Alice', 'Engineering'),
  (2, 'Bob', 'Sales'),
  (3, 'Charlie', 'Marketing')
AS t(id, name, department);

-- Query the table
SELECT * FROM main.bronze.sample;
```

## 🐛 Troubleshooting

### Workspace Not Accessible
```bash
# Check status
terraform output workspace_status  # Should be: RUNNING

# Verify network configuration
terraform state show module.databricks_network_config.databricks_mws_networks.network

# Check NAT Gateways
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"
```

### Unity Catalog Not Visible
```bash
# Verify metastore assignment
terraform output metastore_assigned_to_workspace  # Should be: true

# Check IAM role permissions
aws iam get-role --role-name <project>-<env>-cross-account-role

# Verify data access configuration
terraform state show module.databricks_metastore.databricks_metastore_data_access.uc_data_access
```

### Clusters Won't Start
```bash
# Check EC2 permissions (need 52 actions)
terraform state show module.databricks_cross_account_policy.aws_iam_policy.cross_account_compute

# Verify subnet IP availability
aws ec2 describe-subnets --subnet-ids $(terraform output -json private_subnet_ids | jq -r '.[]') \
  --query 'Subnets[*].[SubnetId,AvailableIpAddressCount]'
# Should show 50+ available IPs per subnet

# Check security groups
terraform state show module.security_groups.aws_security_group.databricks
```

## 📚 Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)**: System architecture and design decisions
- **[CROSS_ACCOUNT_SETUP.md](CROSS_ACCOUNT_SETUP.md)**: IAM cross-account trust configuration
- **[DEPLOYMENT_STEPS.md](DEPLOYMENT_STEPS.md)**: Detailed step-by-step deployment guide
- **[COMPLETE_SETUP_SUMMARY.md](COMPLETE_SETUP_SUMMARY.md)**: Comprehensive reference guide

### External Resources
- [Databricks on AWS Documentation](https://docs.databricks.com/administration-guide/cloud-configurations/aws/)
- [Unity Catalog Best Practices](https://docs.databricks.com/data-governance/unity-catalog/)
- [Terraform Databricks Provider](https://registry.terraform.io/providers/databricks/databricks/)

## 🔐 Security Considerations

### External ID (Confused Deputy Prevention)
- IAM trust policy requires External ID (your Databricks account UUID)
- Prevents attackers from assuming your IAM role even with role ARN
- Acts as shared secret between you and Databricks

### Network Security
- Private subnets only (no direct internet access)
- Security Groups: Intra-cluster only (TCP 443, 8443-8451)
- NACLs: Additional stateless filtering layer
- VPC Endpoints: Keep S3/STS traffic within AWS network

### Encryption
- **Current**: SSE-S3 (AES-256, free, AWS-managed)
- **Optional**: KMS (~$1-5/month, customer-controlled)
- **Recommendation**: SSE-S3 for dev/standard, KMS for compliance (HIPAA, PCI-DSS, FedRAMP)

## 🎓 Key Concepts

### Unity Catalog Storage Model
**Modern Best Practice (2024-2025)**:
- Metastore: NO storage_root (metadata-only)
- Catalogs: Each has MANAGED LOCATION 's3://bucket/catalog/'
- Tables: Use MANAGED tables (NOT external)
- Benefits: Predictive optimization, liquid clustering, auto-VACUUM

**Deprecated Approach**:
- Metastore with storage_root
- All data in single location
- Limited optimization features

### Networking Architecture
- **Private Subnets**: Databricks clusters (no direct internet)
- **Public Subnets**: NAT Gateways only (not for compute)
- **NAT Gateway per AZ**: High availability, fault tolerance
- **VPC Endpoints**: Reduce NAT Gateway costs for S3/STS

### IAM Permissions
- **Storage Policy**: S3, KMS, STS, file events
- **Compute Policy**: 52 EC2 actions (RunInstances, Spot, Fleet, Launch Templates)
- **External ID**: Prevents confused deputy attacks

## 🚧 Production Readiness

### Before Production Deployment
- [ ] Migrate to S3 backend with DynamoDB locking
- [ ] Enable KMS encryption (if compliance requires)
- [ ] Configure AWS Config and Security Hub
- [ ] Set up CloudWatch alarms and dashboards
- [ ] Enable S3 versioning and cross-region replication
- [ ] Configure budget alerts in AWS Cost Explorer
- [ ] Document disaster recovery procedures
- [ ] Implement Terraform plan approval workflow
- [ ] Use AWS Secrets Manager for credentials
- [ ] Set up monitoring and alerting

### Remote State Backend
```hcl
# Add to versions.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "databricks/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

## 📞 Support

### Issues and Questions
- Review documentation files (ARCHITECTURE.md, CROSS_ACCOUNT_SETUP.md, etc.)
- Check Databricks documentation: https://docs.databricks.com/
- Consult Terraform provider docs: https://registry.terraform.io/providers/databricks/databricks/

### Contributing
This is a reference implementation. For production use:
1. Fork the repository
2. Adjust for your organization's requirements
3. Test in non-production environment first
4. Review security and compliance requirements

## ⚖️ License

This project is provided as-is for educational and reference purposes.

## ✅ Validation Status

- [x] Terraform validation passed
- [x] All 17 modules created
- [x] Dependencies explicitly defined
- [x] Security best practices implemented
- [x] Multi-AZ high availability
- [x] Unity Catalog modern architecture
- [x] Comprehensive documentation
- [x] Cost-optimized configuration

---

**Last Updated**: 2025-10-24
**Terraform Version**: >= 1.13.4
**AWS Provider**: 6.17.0
**Databricks Provider**: 1.94.0

🎉 **Ready for deployment!**
