# Databricks on AWS - Enterprise Terraform Infrastructure# Databricks AWS Terraform Setup



[![Terraform](https://img.shields.io/badge/Terraform-≥1.13.4-623CE4?logo=terraform)](https://www.terraform.io/)Production-ready **Databricks workspace** deployment on AWS Premium tier with modern best practices.

[![Databricks](https://img.shields.io/badge/Databricks-~>1.95.0-FF3621?logo=databricks)](https://registry.terraform.io/providers/databricks/databricks/latest)

[![AWS](https://img.shields.io/badge/AWS-~>6.18.0-FF9900?logo=amazon-aws)](https://registry.terraform.io/providers/hashicorp/aws/latest)## 🚀 Quick Start



Production-ready Terraform infrastructure for deploying Databricks on AWS with Unity Catalog, automated governance, and enterprise security controls.```bash

# 1. Set up credentials

## 🎯 Overviewexport AWS_ACCESS_KEY_ID="your-aws-key"

export AWS_SECRET_ACCESS_KEY="your-aws-secret"

Complete, modular Terraform configuration for Databricks E2 workspaces on AWS Premium tier featuring:export TF_VAR_dbx_acc_client_id="databricks-service-principal-id"

export TF_VAR_dbx_acc_client_secret="databricks-service-principal-secret"

- ✅ **Unity Catalog** - Centralized data governance and access controlexport TF_VAR_dbx_account_id="databricks-account-uuid"

- ✅ **Single-Run Deployment** - Fully automated, zero manual intervention

- ✅ **Enterprise Security** - KMS encryption, VPC isolation, GuardDuty, AWS Config# 2. Configure variables

- ✅ **Cost Optimization** - Auto-termination, spot instances, budget alertscp terraform.tfvars.example terraform.tfvars

- ✅ **Production-Ready** - 29 modular components, extensively tested# Edit terraform.tfvars with your values



### Deployment Results# 3. Deploy infrastructure

terraform init

| Component | Quantity | Purpose |terraform plan

|-----------|----------|---------|terraform apply

| **AWS Account** | 1 | Dedicated account in AWS Organizations |

| **VPC** | 1 | Multi-AZ with flow logs and DNS |# 4. Access workspace

| **Subnets** | 4 | 2 private + 2 public across 2 AZs |terraform output workspace_url

| **NAT Gateways** | 2 | High availability (one per AZ) |# Open URL and login with account admin credentials

| **Security Groups** | 2 | Workspace + VPC endpoints |```

| **VPC Endpoints** | 2 | S3 Gateway + EC2 Interface |

| **Databricks Workspace** | 1 | E2 Premium tier with Unity Catalog |## 📋 What Gets Deployed

| **Unity Catalog Metastore** | 1 | Centralized data governance |

| **Catalogs** | 1 | datapact catalog with default schema |### Infrastructure (17 Modules)

| **Cluster Policies** | 3 | Data engineering, analyst, admin |

| **Service Principals** | 2 | Terraform + job runner automation |**Networking (9 modules)**

- VPC with DNS resolution and flow logs

**Estimated Cost:** $230-500/month for dev/sandbox environment- Private subnets (/26, Databricks minimum) across multiple AZs

- Public subnets (/28) for NAT Gateways only

---- Internet Gateway for public subnet egress

- NAT Gateways (one per AZ for high availability)

## 🚀 Quick Start- Route tables (private → NAT, public → IGW)

- Security Groups (intra-cluster + HTTPS egress)

### Prerequisites- VPC Endpoints (S3 + STS gateway endpoints)

- Network ACLs (defense-in-depth stateless filtering)

1. **AWS:** Account with Organizations access, AWS CLI configured

2. **Databricks:** Account admin service principal credentials**Storage & IAM (4 modules)**

3. **Tools:** Terraform ≥ 1.13.4, AWS CLI ≥ 2.x, Git- S3 root bucket (SSE-S3 encrypted, versioned)

- IAM role with External ID (confused deputy prevention)

### Deploy in 5 Steps- IAM storage policy (S3, KMS, STS, file events)

- IAM compute policy (52 EC2 actions, Spot permissions)

```bash

# 1. Clone repository**Databricks Account (2 modules)**

git clone <repo-url> && cd dbx-aws-tf-dev- Storage configuration (MWS credentials + storage)

- Network configuration (VPC registration)

# 2. Create terraform.tfvars (see Configuration section)

cp terraform.tfvars.example terraform.tfvars**Data Governance (1 module)**

# Edit with your values- Unity Catalog metastore (NO storage_root, modern best practice)



# 3. Initialize Terraform**Workspace (1 module)**

terraform init- Databricks E2 workspace (Premium tier, Unity Catalog enabled)



# 4. Review plan## 🏗️ Architecture

terraform plan -out=tfplan

```

# 5. Deploy (15-20 minutes)┌─────────────────────────────────────────────┐

terraform apply tfplan│      DATABRICKS CONTROL PLANE               │

```│   (Databricks-Managed AWS Account)          │

│   - Web UI, Notebooks, SQL Editor           │

### Configuration│   - Unity Catalog Metadata ($0 cost)        │

└──────────────────┬──────────────────────────┘

Create `terraform.tfvars`:                   │ Cross-Account IAM

                   │ (External ID Security)

```hcl┌──────────────────▼──────────────────────────┐

# Core Settings│      YOUR AWS ACCOUNT (Customer VPC)        │

project_name = "dbx-tf"├─────────────────────────────────────────────┤

env          = "-dev"│  VPC: 10.0.0.0/24 (customizable)            │

aws_region   = "us-east-2"│  ├─ Private Subnets: 2× /26 (Databricks)   │

│  ├─ Public Subnets: 2× /28 (NAT GW only)   │

# Databricks Account│  ├─ NAT Gateways: High availability         │

dbx_account_id        = "12345678-1234-1234-1234-123456789abc"│  ├─ Security Groups: Zero-trust egress      │

dbx_acc_client_id     = "service-principal-client-id"│  └─ VPC Endpoints: S3 + STS (cost savings)  │

dbx_acc_client_secret = "service-principal-secret"│                                              │

│  S3 Root Bucket:                            │

# Unity Catalog│  ├─ Cluster logs, notebooks, libraries      │

dbx_metastore_owner_email = "admin@yourdomain.com"│  ├─ SSE-S3 encryption (AES-256)            │

catalog_name              = "datapact"│  └─ Versioning enabled                      │

catalog_owner_email       = "admin@yourdomain.com"│                                              │

│  Unity Catalog:                             │

# User Management│  ├─ Regional metastore (no storage root)    │

admin_email                 = "admin@yourdomain.com"│  ├─ Catalog-level managed locations         │

workspace_admin_email       = "admin@yourdomain.com"│  └─ Managed tables (optimized features)     │

data_engineers_group_name   = "data_engineers"└─────────────────────────────────────────────┘

assign_data_engineers_group = true```



# AWS Account## 📊 Key Features

account_email       = "aws-databricks-dev@yourdomain.com"

parent_ou_id        = "ou-xxxx-yyyyyyyy"### Security

aws_acc_switch_role = "arn:aws:iam::123456789012:role/OrganizationAccountAccessRole"- ✅ **External ID** prevents confused deputy attacks

- ✅ **Zero-trust networking** (private subnets only)

# Network- ✅ **Defense-in-depth** (Security Groups + NACLs)

vpc_cidr_block         = "10.0.0.0/16"- ✅ **Encryption at rest** (SSE-S3, KMS optional)

subnet_count           = 2- ✅ **Least-privilege IAM** policies

private_subnet_newbits = 3  # /19 subnets

public_subnet_newbits  = 4  # /20 subnets### High Availability

- ✅ **Multi-AZ deployment** (minimum 2 AZs)

# Cost Management- ✅ **NAT Gateway per AZ** (fault tolerance)

monthly_budget_limit = 500- ✅ **Subnet redundancy** (automatic failover)

dbu_budget_limit     = 1000

budget_alert_emails  = ["admin@yourdomain.com"]### Cost Optimization

- ✅ **VPC Endpoints** (avoid NAT Gateway charges for S3/STS)

# Tags- ✅ **Auto-termination** (configurable idle timeout)

aws_tags = {- ✅ **Spot instances** support (60-90% savings)

  Project     = "Databricks"- ✅ **S3 Bucket Keys** (reduce KMS costs if using KMS)

  Environment = "Development"

  ManagedBy   = "Terraform"### Modern Best Practices

}- ✅ **Unity Catalog** without storage_root

```- ✅ **Catalog-level managed locations** (not metastore-level)

- ✅ **Managed tables** recommended (NOT external)

---- ✅ **Modular architecture** (17 independent modules)

- ✅ **Terraform 1.13+** compatible

## 🏗️ Architecture- ✅ **AWS Provider 6.18.0** (October 2024)

- ✅ **Databricks Provider 1.95.0** (October 2024)

```

AWS Organizations## 💰 Cost Estimate

└── Databricks Dev Account

    ├── VPC (10.0.0.0/16)### Fixed Monthly Costs

    │   ├── Private Subnets (2 AZs)| Component     | Quantity | Unit Cost   | Monthly         |

    │   │   └── Databricks Compute (EC2)| ------------- | -------- | ----------- | --------------- |

    │   ├── Public Subnets (2 AZs)| NAT Gateway   | 2        | $0.045/hour | $65             |

    │   │   └── NAT Gateways (HA)| NAT Transfer  | Variable | $0.045/GB   | ~$20            |

    │   ├── Security Groups| VPC Endpoints | 2        | $0.01/hour  | $14             |

    │   ├── Network ACLs| S3 Storage    | Variable | $0.023/GB   | ~$23/TB         |

    │   └── VPC Endpoints (S3 + EC2)| **Subtotal**  |          |             | **~$100/month** |

    │

    ├── Databricks Workspace### Variable Databricks Costs (DBU-based)

    │   ├── Premium Tier| Workload     | DBU Rate  | Example Usage    | Monthly        |

    │   ├── Unity Catalog Enabled| ------------ | --------- | ---------------- | -------------- |

    │   └── OAuth M2M Auth| Jobs Compute | $0.15/DBU | 100 hrs × 2 DBUs | $30            |

    │| All-Purpose  | $0.55/DBU | 40 hrs × 2 DBUs  | $44            |

    ├── Unity Catalog| SQL Compute  | $0.22/DBU | 80 hrs × 1 DBU   | $18            |

    │   ├── Metastore (us-east-2)| **Subtotal** |           |                  | **~$92/month** |

    │   ├── Storage Credential (IAM)

    │   ├── External Location (S3)**Total Estimate**: ~**$192/month** for moderate usage

    │   └── Catalog: datapact

    │### Cost Reduction Tips

    ├── Storage (S3 + KMS)1. Enable auto-termination (15-30 minutes)

    │   ├── Workspace Root (DBFS)2. Use Spot instances for fault-tolerant workloads

    │   └── Unity Catalog Data3. Set cluster policies (restrict instance types)

    │4. Monitor DBU usage in billing dashboard

    └── Security & Compliance5. Use VPC endpoints (included above, saves NAT costs)

        ├── GuardDuty

        ├── AWS Config## 📁 Project Structure

        ├── VPC Flow Logs

        └── Budget Alerts```

```.

├── main.tf                         # Root module (16 deployment steps)

**Key Principles:**├── variables.tf                    # Input variables with validation

- Multi-AZ high availability├── outputs.tf                      # Infrastructure outputs

- Private subnet compute isolation  ├── providers.tf                    # AWS + Databricks provider config

- KMS encryption for all storage├── versions.tf                     # Terraform version constraints

- Least privilege IAM roles├── terraform.tfvars                # User-specific values (gitignored)

- Cost optimization built-in│

├── ARCHITECTURE.md                 # Detailed architecture documentation

---├── CROSS_ACCOUNT_SETUP.md          # IAM cross-account trust guide

├── DEPLOYMENT_STEPS.md             # Step-by-step deployment guide

## 📁 Repository Structure├── COMPLETE_SETUP_SUMMARY.md       # Comprehensive reference

└── README.md                       # This file

```│

.└── modules/                        # 17 independent modules

├── README.md                  # This file    ├── aws_vpc/                    # VPC with DNS and flow logs

├── main.tf                    # Root module orchestration    ├── aws_subnets/                # Multi-AZ private/public subnets

├── variables.tf               # Input variable declarations    ├── aws_internet_gateway/       # Internet access for public subnets

├── outputs.tf                 # Output values    ├── aws_nat_gateway/            # NAT for private subnet egress

├── providers.tf               # Provider configurations    ├── aws_route_tables/           # Routing configuration

├── versions.tf                # Version constraints    ├── aws_security_groups/        # Network security rules

├── terraform.tfvars           # Variable values (gitignored)    ├── aws_vpc_endpoints/          # S3/STS gateway endpoints

├── .editorconfig              # Code style rules    ├── aws_network_acls/           # Stateless filtering

│    ├── aws_account/                # AWS account creation (optional)

├── docs/                      # Documentation    ├── databricks_s3_root_bucket/  # Root storage bucket

│   ├── STYLE_GUIDE.md        # Code standards    ├── databricks_iam_role/        # Cross-account IAM role

│   ├── ARCHITECTURE.md       # Detailed architecture    ├── databricks_iam_policy/      # Storage permissions

│   ├── DEPLOYMENT_STEPS.md   # Deployment guide    ├── databricks_cross_account_policy/ # Compute permissions (52 EC2 actions)

│   └── ...                   # Additional docs    ├── databricks_storage_config/  # MWS storage + credentials

│    ├── databricks_network_config/  # MWS network registration

└── modules/                   # 29 reusable modules    ├── databricks_metastore/       # Unity Catalog metastore

    ├── aws_vpc/              # VPC with flow logs    └── databricks_workspace/       # Workspace creation

    ├── aws_subnets/          # Multi-AZ subnets```

    ├── databricks_workspace/ # E2 workspace

    ├── databricks_metastore/ # Unity Catalog## 🔧 Prerequisites

    ├── databricks_cluster_policies/  # Governance

    └── ...                   # Other modules### Required Tools

```- **Terraform**: >= 1.13.4

- **AWS CLI**: >= 2.0 (for credential management)

---- **Git**: For version control



## 🔐 Security Features### Required Credentials



### Encryption#### AWS Credentials

- ✅ KMS customer-managed keys for S3```bash

- ✅ EBS encryption enforced via AWS Configexport AWS_ACCESS_KEY_ID="your-access-key"

- ✅ TLS 1.2+ for all communicationsexport AWS_SECRET_ACCESS_KEY="your-secret-key"

- ✅ Terraform state encryptionexport AWS_DEFAULT_REGION="us-east-2"  # Optional

```

### Network Security

- ✅ Private subnets for all computeOr configure via `~/.aws/credentials`:

- ✅ Security groups (least privilege)```ini

- ✅ Network ACLs (stateless firewall)[default]

- ✅ VPC Flow Logs (30-day retention)aws_access_key_id = your-access-key

aws_secret_access_key = your-secret-key

### Monitoring```

- ✅ GuardDuty (threat detection)

- ✅ AWS Config (8 compliance rules)#### Databricks Credentials

- ✅ CloudWatch Logs1. **Create Service Principal** (Account Console → User Management → Service Principals)

- ✅ Budget alerts (4 thresholds)2. **Assign Account Admin** role

3. **Generate OAuth Secret**

### IAM Best Practices4. **Export credentials**:

- ✅ Specific role ARNs (no `:root`)```bash

- ✅ External ID conditionsexport TF_VAR_dbx_account_id="12345678-1234-1234-1234-123456789012"

- ✅ Path-scoped permissionsexport TF_VAR_dbx_acc_client_id="service-principal-id"

- ✅ No wildcard resourcesexport TF_VAR_dbx_acc_client_secret="service-principal-secret"

```

---

## 📝 Configuration

## 💰 Cost Management

### terraform.tfvars Example

### Monthly Cost Estimate```hcl

# AWS Configuration

| Component | Cost | Notes |aws_region           = "us-east-2"

|-----------|------|-------|project_name         = "dbx-tf"

| NAT Gateways | $65 | 2 × $0.045/hour |env                  = "dev"

| NAT Data Transfer | $20-50 | Based on usage |

| VPC Endpoints | $7 | EC2 interface |# Databricks Account

| VPC Flow Logs | $5 | 30 days |dbx_account_id              = "12345678-1234-1234-1234-123456789012"

| S3 Storage | $15-70 | Workspace + UC |dbx_metastore_owner_email   = "admin@company.com"  # Must be account admin

| KMS | $1 | 1 key |

| GuardDuty | $5-10 | Based on data volume |# Networking

| AWS Config | $3 | 8 rules |vpc_cidr_block              = "10.0.0.0/24"  # 256 IPs (demo size)

| Databricks Compute | $80-200 | 200-500 DBUs/month |subnet_count                = 2              # Number of AZs

| EC2 Spot Instances | $30-100 | 70% discount |private_subnet_newbits      = 2              # /26 subnets (64 IPs, Databricks min)

| **Total** | **$230-500** | Dev environment |public_subnet_newbits       = 4              # /28 subnets (16 IPs, NAT GW only)



### Cost Optimization# Tags

- Auto-termination (10-60 min idle)aws_tags = {

- Spot instances (~70% savings)  Project     = "Databricks-TF"

- Autoscaling (1-20 workers)  Environment = "Development"

- Budget alerts (50%, 80%, 100%, 120%)  ManagedBy   = "Terraform"

- Photon engine (3-5x faster)  CostCenter  = "Engineering"

}

---```



## 🧪 Testing & Validation### Production Adjustments

```hcl

```bash# Larger VPC for production

# Pre-deploymentvpc_cidr_block         = "10.0.0.0/20"  # 4,096 IPs

terraform validateprivate_subnet_newbits = 3              # /23 subnets (512 IPs per AZ)

terraform fmt -recursivepublic_subnet_newbits  = 6              # /26 subnets (64 IPs per AZ)

terraform plan -out=tfplansubnet_count           = 3              # 3 AZs for higher availability



# Post-deployment verification# Production environment

terraform output workspace_urlenv = "-prod"

``````



```sql## 🚀 Deployment

-- Unity Catalog verification

USE CATALOG datapact;### Step 1: Initialize Terraform

SHOW SCHEMAS;```bash

SHOW GRANTS ON CATALOG datapact;terraform init -upgrade

```# Downloads providers and modules

# Takes ~30 seconds

---```



## 🔄 Maintenance### Step 2: Validate Configuration

```bash

### Update Infrastructureterraform validate

```bash# Checks syntax and configuration

git pull origin main# Takes ~5 seconds

terraform init -upgrade```

terraform plan -out=tfplan

terraform apply tfplan### Step 3: Plan Deployment

``````bash

terraform plan -out=tfplan

### Backup State# Shows what will be created

```bash# Review carefully before applying

aws s3 cp s3://databricks-terraform-state-<account-id>/terraform.tfstate \# Takes ~30 seconds

  ./backups/terraform.tfstate.$(date +%Y%m%d)```

```

### Step 4: Apply Infrastructure

### Destroy (Dev Only)```bash

```bashterraform apply tfplan

terraform destroy# Creates all 17 modules

```# Takes ~15-20 minutes total:

#   - Networking: 5 minutes

---#   - Storage/IAM: 2 minutes

#   - Databricks configs: 3 minutes

## 📚 Documentation#   - Metastore: 1 minute

#   - Workspace: 8-12 minutes

- [Style Guide](docs/STYLE_GUIDE.md) - Code standards```

- [Architecture](docs/ARCHITECTURE.md) - Detailed design

- [Deployment](docs/DEPLOYMENT_STEPS.md) - Step-by-step guide### Step 5: Access Workspace

- [Identity Management](docs/IDENTITY_MANAGEMENT_STRATEGY.md) - SCIM integration```bash

- [Complete Reference](docs/COMPLETE_SETUP_SUMMARY.md) - Full config# Get workspace URL

terraform output workspace_url

---# Output: https://dbx-tf-dev-us-east-2.cloud.databricks.com



## 🆘 Troubleshooting# Get workspace ID

terraform output workspace_id

**Provider download errors:**# Output: 1234567890123456

```bash

terraform providers mirror ./terraform-providers# Get all outputs

terraform init -plugin-dir=./terraform-providersterraform output

``````



**IAM propagation failures:**## 🔍 Post-Deployment

```hcl

resource "time_sleep" "wait_for_iam_propagation" {### 1. Initial Login

  create_duration = "180s"  # Increase wait time```

}URL: <terraform output workspace_url>

```Credentials: Account admin (SSO or username/password)

First login: 2-3 minutes for workspace initialization

**Sensitive output errors:**```

```hcl

output "secret" {### 2. Create Unity Catalog Structure

  value     = var.secret```sql

  sensitive = true-- Create main catalog with managed location

}CREATE CATALOG main

```MANAGED LOCATION 's3://<your-root-bucket>/catalogs/main/';



----- Create schemas (Bronze/Silver/Gold medallion architecture)

CREATE SCHEMA main.bronze COMMENT 'Raw ingested data';

## 📞 SupportCREATE SCHEMA main.silver COMMENT 'Cleaned and validated data';

CREATE SCHEMA main.gold COMMENT 'Business-level aggregates';

- 📖 [Databricks Docs](https://docs.databricks.com/)

- 📖 [Terraform Provider](https://registry.terraform.io/providers/databricks/databricks/latest/docs)-- Grant permissions

- 📖 [AWS Docs](https://docs.aws.amazon.com/)GRANT USE CATALOG ON main TO `account users`;

GRANT USE SCHEMA ON ALL SCHEMAS IN CATALOG main TO `account users`;

---

-- Create development catalog

**Version:** October 2025  CREATE CATALOG dev

**Terraform:** >= 1.13.4  MANAGED LOCATION 's3://<your-root-bucket>/catalogs/dev/';

**Databricks Provider:** ~> 1.95.0  ```

**AWS Provider:** ~> 6.18.0

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
**AWS Provider**: 6.18.0
**Databricks Provider**: 1.95.0

🎉 **Ready for deployment!**
