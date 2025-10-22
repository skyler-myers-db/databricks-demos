# Runbook — Databricks on AWS (Enterprise + Premium-Sim)

This runbook describes how to deploy the stack, how secrets are handled, and what to toggle between **Enterprise** and **Premium**.

## 0) Prereqs
- Terraform >= 1.13.4
- AWS account with permissions to create VPC/NAT/IGW/VPCE/KMS/S3/IAM/Route53
- A Databricks Account Admin service principal (OAuth) — pass `DATABRICKS_ACCOUNT_ID`, `DATABRICKS_CLIENT_ID`, `DATABRICKS_CLIENT_SECRET` via CI/CD or `.env`
- For workspace provider: either a **Workspace OAuth app** or a PAT. Prefer OAuth.
- If using **PrivateLink**, you need Enterprise plan and must follow Databricks docs for registering VPCEs and DNS mapping

## 1) Choose an environment
- `envs/enterprise/terraform.tfvars.example` — copy to `terraform.tfvars` and fill in all fields. Set `enable_privatelink_backend=true` and `enable_privatelink_frontend=true`.
- `envs/premium-sim/terraform.tfvars.example` — Premium safe subset. Enterprise only blocks are in code but gated by variables and inline comments.

## 2) Initialize & plan
```
cd envs/<enterprise|premium-sim>
terraform init
terraform plan -out plan.tfplan
```
If using remote state, configure in `backend.hcl` or your backend block of choice.

## 3) Apply
```
terraform apply plan.tfplan
```
The apply creates:
- VPC with private subnets (2+ AZs), NAT, IGW, SGs, NACLs
- S3 buckets (root, logs) + KMS CMK and hardened bucket policies (VPCE, SSL, encryption)
- IAM cross-account role for Databricks
- (Optional) VPCEs for **back‑end PrivateLink**: **Relay** (SCC) + **Workspace REST API** and registers them with Databricks
- Databricks **network configuration** and **Private Access Settings** objects
- Workspace (customer-managed VPC) wired to objects above
- UC Metastore + assignment; storage credential + external location; sample Catalogs/Schemas
- (Optional) Federation connection + **Foreign Catalog** sample when enabled
- System tables enablement
- Log delivery configuration (audit/usage/rsyslog) to log bucket
- Flow logs and account-level S3 Public Access Block

> After workspace is created, capture outputs `workspace_url` and `workspace_id`. For **front‑end PL**, supply the `frontend_vpce_ips` and set DNS via `dns_privatelink` module

## 4) Deploy workspace artifacts via **Databricks Asset Bundles**
```
cd bundles/platform
# Set DATABRICKS_HOST & DATABRICKS_TOKEN or OAuth env vars for the workspace
databricks bundle validate
databricks bundle deploy    # creates jobs/warehouses/schemas/volumes/etc.
```
See `bundles/platform/README.md` for details. Supported resource types: jobs, pipelines, clusters, sql_warehouses, registered models, schemas, volumes, dashboards, secret scopes, apps, etc.

## 5) CI/CD
- **Terraform:** `.github/workflows/terraform.yml` runs `fmt/validate/plan` on PRs and applies on main with manual approval.
- **Bundles:** `.github/workflows/bundles.yml` runs `bundle validate` on PRs and deploys on tagged releases or main.

## Secrets & parameters
- Keep *all* sensitive values in CI/CD **environment secrets** (GitHub Actions) or a local `.env` not committed. For federation DB password, prefer short lived creds or AWS Secrets Manager; Terraform marks option as sensitive but it may still appear in state metadata.
- For DABs, put passwords/tokens into **workspace secret scopes** and reference via task/environment variables.

## Premium vs Enterprise
- Premium cannot enable PrivateLink or PAS; keep those modules but leave `enable_privatelink_* = false`. Enterprise-only code is annotated with `# ENTERPRISE-ONLY` comments
- Everything else (VPC, S3, UC, jobs, pipelines, permissions) works on Premium.

## Disaster recovery & drift
- Re-run `terraform plan` regularly and enable **Drift detection** in CI (scheduled plan)
- Export manually-created artifacts with the Databricks **terraform exporter** if needed, then refactor into DAB or TF

## Troubleshooting
- Workspace creation errors often relate to **network config or VPCE registration** order; verify that network configuration references registered VPCEs and that subnets/SGs meet docs requirements
- For system tables, ensure VPC endpoint policy allows access to the region’s **system tables S3 bucket** if you use a customer managed VPC
