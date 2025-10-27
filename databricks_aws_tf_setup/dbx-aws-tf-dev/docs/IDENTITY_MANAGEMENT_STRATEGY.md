# Identity & Access Management Strategy for Databricks

**Purpose**: Minimize user and group management overhead by syncing identity from source of truth (G-Suite for dev, Okta for enterprise clients)

**Date**: January 2025
**Databricks Tier**: Premium (current) / Enterprise (client deployments)

---

## Table of Contents

1. [Overview](#overview)
2. [Current State](#current-state)
3. [Enterprise Client Best Practice (Okta)](#enterprise-client-best-practice-okta)
4. [Your Environment (G-Suite + Premium Tier)](#your-environment-g-suite--premium-tier)
5. [Recommended Implementation](#recommended-implementation)
6. [AWS IAM Integration](#aws-iam-integration)
7. [Terraform Implementation](#terraform-implementation)
8. [Migration Path](#migration-path)

---

## Overview

### The Problem
Manual user management across multiple systems creates:
- ⚠️ Security risks (orphaned accounts, delayed offboarding)
- ⚠️ Operational overhead (duplicate user creation)
- ⚠️ Compliance gaps (inconsistent access control)
- ⚠️ Audit complexity (multiple sources of truth)

### The Solution: SCIM Provisioning
**System for Cross-domain Identity Management (SCIM)** automates:
- ✅ User creation/updates/deletion
- ✅ Group membership synchronization
- ✅ Attribute mapping (email, name, role)
- ✅ Single source of truth (identity provider)

### SCIM Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                     Identity Provider                        │
│              (Okta, Azure AD, G-Suite, etc.)                │
│                                                              │
│  Users + Groups + Attributes (source of truth)              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ SCIM 2.0 Protocol
                       │ (Real-time sync)
                       ↓
┌──────────────────────────────────────────────────────────────┐
│              Databricks Account Console                       │
│                 (Account-Level SCIM)                          │
│                                                               │
│  ├─ Users (synced from IdP)                                  │
│  ├─ Service Principals (manual or API)                       │
│  └─ Groups (synced from IdP)                                 │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       │ Automatic Assignment
                       ↓
┌──────────────────────────────────────────────────────────────┐
│                 Databricks Workspaces                         │
│            (Inherit users/groups from account)               │
│                                                               │
│  Workspace 1 (Dev)    Workspace 2 (Prod)   Workspace 3 (QA) │
└──────────────────────────────────────────────────────────────┘
```

---

## Current State

### What Exists Now
- ✅ AWS infrastructure (VPC, IAM roles, S3 buckets)
- ✅ Databricks workspace (Premium tier)
- ✅ Unity Catalog metastore (account-level data governance)
- ⏳ No automated identity provisioning

### Manual Process (Current)
1. User joins organization → Added to G-Suite
2. Admin manually creates user in Databricks account console
3. Admin assigns user to workspace(s)
4. Admin assigns user to groups (data_engineers, data_analysts, etc.)
5. Admin grants Unity Catalog permissions
6. User leaves → Admin manually removes from Databricks

**Time Cost**: ~10-15 minutes per user lifecycle event
**Risk**: Delayed offboarding, inconsistent permissions

---

## Enterprise Client Best Practice (Okta)

### Why Okta for Enterprise?

Enterprise organizations prefer Okta because:
- ✅ Native Databricks integration (pre-built connector)
- ✅ Real-time SCIM provisioning (create/update/delete)
- ✅ SSO with Databricks (SAML 2.0)
- ✅ Group-based access control (map Okta groups → Databricks groups)
- ✅ Audit logs (complete identity lifecycle)
- ✅ Compliance certifications (SOC 2, ISO 27001, FedRAMP)

### Okta + Databricks Architecture (Enterprise Tier)

```
┌─────────────────────────────────────────────────────────────┐
│                         Okta                                 │
│                  (Identity Provider)                         │
│                                                              │
│  Users:                  Groups:                             │
│  - alice@company.com     - data_engineers                    │
│  - bob@company.com       - data_analysts                     │
│  - charlie@company.com   - workspace_admins                  │
│                          - databricks_users                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ SCIM 2.0 + SAML 2.0
                       │ (Automated sync + SSO)
                       ↓
┌──────────────────────────────────────────────────────────────┐
│            Databricks Account (Enterprise Tier)              │
│                                                               │
│  SCIM Configuration:                                          │
│  - Endpoint: https://accounts.cloud.databricks.com/api/2.0/  │
│              preview/scim/v2                                  │
│  - Token: Service Principal OAuth token                       │
│  - Sync: Real-time (provisioning/deprovisioning)             │
│                                                               │
│  Users (synced):          Groups (synced):                   │
│  - alice@company.com      - data_engineers                   │
│  - bob@company.com        - data_analysts                    │
│  - charlie@company.com    - workspace_admins                 │
│                                                               │
│  Workspaces:                                                  │
│  - Dev workspace (data_engineers, workspace_admins)          │
│  - Prod workspace (data_engineers, workspace_admins only)    │
└──────────────────────────────────────────────────────────────┘
```

### Okta Setup Steps (Enterprise Clients)

#### Prerequisites
- ✅ Databricks Enterprise tier license
- ✅ Okta subscription (Workforce Identity or higher)
- ✅ Databricks account admin access
- ✅ Okta admin access

#### Step 1: Create Databricks App in Okta
```
Okta Admin Console → Applications → Browse App Integration Catalog
→ Search "Databricks" → Add Integration

Configuration:
- Name: Databricks Production
- Sign-On Method: SAML 2.0
- SCIM Provisioning: Enabled
```

#### Step 2: Configure SAML SSO
```
Databricks Account Console → Settings → Authentication

SSO Configuration:
- Sign-On URL: <from Okta app config>
- Issuer: <from Okta app config>
- Certificate: <upload from Okta>
- Sign-Out URL: <from Okta app config>
```

#### Step 3: Configure SCIM Provisioning in Okta
```
Okta Databricks App → Provisioning → Configure API Integration

SCIM Configuration:
- Base URL: https://accounts.cloud.databricks.com
- API Token: <Databricks service principal OAuth token>
- Authentication: Bearer Token

Enable:
✅ Create Users
✅ Update User Attributes
✅ Deactivate Users
✅ Sync Groups (push groups from Okta)
```

#### Step 4: Create Service Principal in Databricks
```bash
# Use Databricks CLI or Terraform
databricks service-principals create --name "okta-scim-connector"
databricks service-principals assign --id <sp-id> --role account_admin
databricks service-principals generate-oauth-token --id <sp-id>
```

#### Step 5: Configure Attribute Mapping
```
Okta → Databricks App → Provisioning → To App

Attribute Mappings:
- userName: user.email (required)
- displayName: user.displayName
- name.givenName: user.firstName
- name.familyName: user.lastName
- emails[type eq "work"].value: user.email
- active: user.status
- groups: Okta groups → Databricks groups (group push)
```

#### Step 6: Assign Users and Groups
```
Okta → Databricks App → Assignments

Assign:
- Individual users: alice@company.com, bob@company.com
- Groups: data_engineers, data_analysts, workspace_admins

Group Rules (optional):
- IF user.department == "Data Engineering"
  THEN assign to group "data_engineers"
```

#### Step 7: Test Provisioning
```
Okta → Databricks App → Provisioning → Provision User

Verify in Databricks:
1. User appears in Account Console → User Management
2. User can SSO login with Okta credentials
3. Groups are synced and memberships correct
4. User can access assigned workspaces
```

### Terraform Implementation (Okta + Databricks Enterprise)

```hcl
# modules/databricks_scim_okta/main.tf
# NOTE: This is for ENTERPRISE TIER clients with Okta
# Requires: databricks_provider >= 1.94.0, okta_provider >= 4.0

# ============================================================================
# OKTA PROVIDER CONFIGURATION
# ============================================================================
terraform {
  required_providers {
    okta = {
      source  = "okta/okta"
      version = "~> 4.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.94.0"
    }
  }
}

# Okta provider (requires OKTA_ORG_NAME, OKTA_API_TOKEN env vars)
provider "okta" {
  org_name  = var.okta_org_name  # e.g., "company"
  base_url  = var.okta_base_url  # e.g., "okta.com" or "oktapreview.com"
}

# ============================================================================
# DATABRICKS SERVICE PRINCIPAL FOR SCIM
# ============================================================================
# Create dedicated service principal for Okta SCIM provisioning

resource "databricks_service_principal" "okta_scim" {
  provider       = databricks.mws
  display_name   = "okta-scim-provisioner"
  application_id = var.okta_application_id  # From Okta app config
  active         = true
}

# Assign account admin role (required for SCIM provisioning)
resource "databricks_account_role" "okta_scim_admin" {
  provider             = databricks.mws
  service_principal_id = databricks_service_principal.okta_scim.id
  role                 = "account_admin"
}

# Generate OAuth token for SCIM authentication
resource "databricks_oauthtoken" "okta_scim" {
  provider             = databricks.mws
  service_principal_id = databricks_service_principal.okta_scim.id
  lifetime_seconds     = 31536000  # 1 year, rotate annually
  comment              = "Okta SCIM provisioning token"
}

# ============================================================================
# OKTA APPLICATION CONFIGURATION
# ============================================================================
# Create Databricks app in Okta (or import existing)

resource "okta_app_saml" "databricks" {
  label                    = "Databricks ${var.environment}"
  status                   = "ACTIVE"
  preconfigured_app        = "databricks"  # Use Okta app catalog template

  # SAML SSO configuration
  sso_url                  = "https://accounts.cloud.databricks.com/login/callback"
  recipient                = "https://accounts.cloud.databricks.com"
  destination              = "https://accounts.cloud.databricks.com"
  audience                 = "https://accounts.cloud.databricks.com"
  subject_name_id_template = "$${user.email}"
  subject_name_id_format   = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"

  # Attribute statements (map Okta user attributes to SAML assertions)
  attribute_statements {
    name      = "email"
    namespace = "urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified"
    type      = "EXPRESSION"
    values    = ["user.email"]
  }

  attribute_statements {
    name      = "firstName"
    namespace = "urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified"
    type      = "EXPRESSION"
    values    = ["user.firstName"]
  }

  attribute_statements {
    name      = "lastName"
    namespace = "urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified"
    type      = "EXPRESSION"
    values    = ["user.lastName"]
  }
}

# ============================================================================
# OKTA SCIM PROVISIONING CONFIGURATION
# ============================================================================

# Note: Okta SCIM provisioning is configured via Okta API, not Terraform
# Use Okta provider's okta_app_user_schema_property for attribute mapping

resource "okta_app_user_schema_property" "databricks_user_id" {
  app_id      = okta_app_saml.databricks.id
  index       = "databricks_user_id"
  title       = "Databricks User ID"
  type        = "string"
  description = "User ID in Databricks (populated by SCIM)"
  master      = "OKTA"
}

# ============================================================================
# OKTA GROUP CONFIGURATION (for group-based access)
# ============================================================================

# Create Okta groups that map to Databricks roles
resource "okta_group" "data_engineers" {
  name        = "Databricks - Data Engineers"
  description = "Data engineering team with full workspace access"
}

resource "okta_group" "data_analysts" {
  name        = "Databricks - Data Analysts"
  description = "Data analysts with read access to curated datasets"
}

resource "okta_group" "workspace_admins" {
  name        = "Databricks - Workspace Admins"
  description = "Administrators with workspace configuration rights"
}

# Assign groups to Databricks app (enables group push)
resource "okta_app_group_assignment" "data_engineers" {
  app_id   = okta_app_saml.databricks.id
  group_id = okta_group.data_engineers.id
}

resource "okta_app_group_assignment" "data_analysts" {
  app_id   = okta_app_saml.databricks.id
  group_id = okta_group.data_analysts.id
}

resource "okta_app_group_assignment" "workspace_admins" {
  app_id   = okta_app_saml.databricks.id
  group_id = okta_group.workspace_admins.id
}

# ============================================================================
# DATABRICKS GROUP CONFIGURATION (Unity Catalog permissions)
# ============================================================================

# Create corresponding groups in Databricks
resource "databricks_group" "data_engineers" {
  provider     = databricks.mws
  display_name = "data_engineers"

  # Note: Users will be auto-added via SCIM group sync from Okta
}

resource "databricks_group" "data_analysts" {
  provider     = databricks.mws
  display_name = "data_analysts"
}

resource "databricks_group" "workspace_admins" {
  provider     = databricks.mws
  display_name = "workspace_admins"
}

# Grant Unity Catalog permissions to groups
resource "databricks_grants" "data_engineers_catalog" {
  provider = databricks.mws
  catalog  = "main"

  grant {
    principal  = "data_engineers"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "CREATE_SCHEMA", "SELECT", "MODIFY"]
  }
}

resource "databricks_grants" "data_analysts_catalog" {
  provider = databricks.mws
  catalog  = "main"

  grant {
    principal  = "data_analysts"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "okta_scim_token" {
  description = "OAuth token for Okta SCIM provisioning (sensitive)"
  value       = databricks_oauthtoken.okta_scim.token_value
  sensitive   = true
}

output "okta_app_id" {
  description = "Okta application ID for Databricks"
  value       = okta_app_saml.databricks.id
}

output "okta_groups" {
  description = "Okta groups configured for Databricks access"
  value = {
    data_engineers   = okta_group.data_engineers.id
    data_analysts    = okta_group.data_analysts.id
    workspace_admins = okta_group.workspace_admins.id
  }
}

# ============================================================================
# MANUAL CONFIGURATION REQUIRED
# ============================================================================
# After Terraform apply, configure SCIM in Okta UI:
#
# 1. Okta Admin Console → Applications → Databricks → Provisioning
# 2. Configure API Integration:
#    - Base URL: https://accounts.cloud.databricks.com
#    - API Token: <terraform output okta_scim_token> (sensitive)
#    - Authentication: Bearer Token
# 3. Enable provisioning features:
#    ✅ Create Users
#    ✅ Update User Attributes
#    ✅ Deactivate Users
#    ✅ Sync Groups (push groups)
# 4. Test provisioning:
#    - Assign test user to Databricks app
#    - Verify user created in Databricks Account Console
#    - Test SSO login
# 5. Configure attribute mappings (if customized)
#
# ============================================================================
```

### Okta + Databricks Benefits (Enterprise)

| Feature                  | Benefit                                       | Impact                      |
| ------------------------ | --------------------------------------------- | --------------------------- |
| Real-time SCIM           | Users provisioned instantly                   | ⏱️ 0 minutes manual work     |
| Automatic deprovisioning | Security compliance (immediate offboarding)   | 🔒 0-day access revocation   |
| Group-based access       | Consistent permissions across workspaces      | 📊 Reduced permission errors |
| SSO (SAML)               | Single login for all tools                    | 🚀 Better user experience    |
| Audit logs               | Complete identity lifecycle tracking          | ✅ Compliance ready          |
| Group push               | Okta groups → Databricks groups automatically | 🔄 Single source of truth    |
