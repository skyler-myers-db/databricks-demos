# Databricks on AWS — Secure, Private, and Modular (Terraform + DAB)

This repo provisions a **from‑scratch Databricks on AWS** environment using Terraform (infra, account, workspace, UC) and **Databricks Asset Bundles (DABs)** for deployable workspace artifacts (jobs, pipelines, models, warehouses, etc)

It supports two target configurations:
- **Enterprise (no public ingress/egress)** — Backend + frontend PrivateLink, IP allow lists optional, egress controls, log delivery, system tables, federation, etc.
- **Premium (simulation)** — Same structure but **Enterprise only features are present in code and commented with `# ENTERPRISE-ONLY`** so you can keep the files consistent but disable them locally

## Layout

```
.
├── envs/
│   ├── enterprise/            # Ideal target: full isolation
│   └── premium-sim/           # sandbox: Premium tier compatible
├── modules/
│   ├── network/               # VPC, subnets, routes, NAT, NACL, SG (workspace)
│   ├── vpc_endpoints/         # Interface + gateway endpoints (S3 GW, STS/Kinesis/RDS IF), PL backend
│   ├── dns_privatelink/       # (Front-end PL) PHZ + A/CNAME records
│   ├── storage/               # Root & log buckets + policies/KMS
│   ├── iam/                   # Cross account role, instance profiles, service principals (optional)
│   ├── databricks_account/    # MWS: credentials, storage config, networks, PAS, VPCE registrations, workspace
│   ├── uc/                    # Metastore, storage creds, external locations, catalogs, schemas, grants, federation
│   ├── workspace/             # Workspace level: system tables, cluster policies, pools, permissions
│   ├── log_delivery/          # MWS log delivery to S3 (audit/usage/rsyslog)
│   └── hardening/             # Flow logs, S3 public access block, (optional) CloudTrail, GuardDuty templates
├── bundles/                   # Databricks Asset Bundles projects (workspace artifacts as code)
│   └── platform/
│       ├── databricks.yml
│       └── resources/
├── .github/workflows/
│   ├── terraform.yml          # Plan + apply on main (requires approvals by default)
│   └── bundles.yml            # Build/validate/deploy DABs
├── RUNBOOK.md                 # Step-by-step deployment and operations
├── providers.tf               # Provider pinning
├── versions.tf                # Terraform version + required providers
├── variables.tf               # Root input variables (wired through env layers)
├── main.tf                    # Composes modules
└── outputs.tf                 # Useful outputs
```

> **Note on Bundles vs Terraform:** Wherever possible, **workspace objects** (jobs, pipelines, warehouses, schemas, volumes, models, dashboards, secret scopes) are expressed via **DAB**. Terraform is used for **cloud & account** primitives (VPC, IAM, S3, MWS workspace/UC, PrivateLink, etc.) or where DAB doesn’t yet cover a feature. See `bundles/platform/databricks.yml`. citeturn8view0
