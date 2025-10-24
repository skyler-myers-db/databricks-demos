# AWS IAM Identity Center + G-Suite + Databricks SCIM Setup Guide

**IMPORTANT**: This guide documents the **one-time manual steps** required to configure AWS IAM Identity Center with G-Suite and Databricks. These steps **cannot be automated with Terraform** due to AWS security restrictions.

**Time Required**: 30-45 minutes (one-time setup)
**Prerequisites**: AWS Organizations enabled, G-Suite admin access, Databricks account admin access

---

## Why These Steps Are Manual

AWS IAM Identity Center has intentional limitations to prevent automated security changes:

1. **Identity Provider Changes**: Require console verification to prevent unauthorized IdP swaps
2. **SAML Metadata Exchange**: Bidirectional trust requires out-of-band file exchange
3. **Shared Service**: One IAM Identity Center instance per AWS Organization (not region-specific)
4. **Security Verification**: Manual approval ensures human oversight of identity system changes

**After these one-time steps, Terraform manages everything else automatically.**

---

## Phase 1: AWS IAM Identity Center Setup (One-Time)

### Step 1: Enable AWS IAM Identity Center

```
AWS Console → IAM Identity Center → Enable

Region: Select your primary region (e.g., us-east-2)
Identity source: AWS Identity Center directory (default - will change to G-Suite later)

Click: Enable IAM Identity Center
```

**Time**: 2-3 minutes
**Can be skipped if**: IAM Identity Center already enabled

### Step 2: Change Identity Source to External Provider

```
AWS Console → IAM Identity Center → Settings → Identity source → Actions → Change identity source

Choose: External identity provider

Download metadata files:
1. Click "Download AWS IAM Identity Center SAML metadata file"
   - Save as: aws-sso-metadata.xml
   - Needed for: G-Suite SAML app configuration (Step 3)

2. Upload IdP SAML metadata (will get from G-Suite in Step 3)
```

**STOP HERE** - Don't finish this step until you configure G-Suite (Step 3)

---

## Phase 2: G-Suite SAML Configuration (One-Time)

### Step 3: Create Custom SAML App in G-Suite

```
G-Suite Admin Console → Apps → Web and mobile apps → Add custom SAML app

App Name: AWS IAM Identity Center
```

#### Step 3a: Download G-Suite IdP Information

```
Option 1 (recommended): Download IdP metadata
- Click "Download metadata"
- Save as: google-idp-metadata.xml
- Use this file in AWS IAM Identity Center (Step 2)

Option 2: Manual configuration
- SSO URL: https://accounts.google.com/o/saml2/idp?idpid=<your-idp-id>
- Entity ID: https://accounts.google.com/o/saml2?idpid=<your-idp-id>
- Certificate: Download certificate
```

#### Step 3b: Configure Service Provider Details (AWS SSO)

```
ACS URL:
  Get from: aws-sso-metadata.xml (from Step 2)
  Format: https://portal.sso.us-east-2.amazonaws.com/saml/assertion

Entity ID:
  Get from: aws-sso-metadata.xml (from Step 2)
  Format: https://us-east-2.signin.aws.amazon.com/saml

Start URL (optional):
  https://your-identity-center-url.awsapps.com/start

Name ID format: EMAIL
Name ID: Basic Information > Primary Email

Signed Response: Unchecked (AWS verifies assertion, not response)
```

#### Step 3c: Configure Attribute Mapping

```
Google Directory Attributes → App Attributes

Required:
- Primary Email        → Subject
- Primary Email        → email
- First Name           → given_name
- Last Name            → family_name

Optional (for better UX):
- Primary Email        → userName
- Employee ID          → employeeNumber
- Department           → department
```

#### Step 3d: Complete G-Suite App Setup

```
1. Turn on for everyone (or specific organizational units)
2. Click "Done"

Note: Users won't use this app directly - it's just for IAM Identity Center trust
```

### Step 4: Complete AWS Identity Source Change

```
Go back to: AWS Console → IAM Identity Center → Settings → Identity source

Upload IdP metadata: google-idp-metadata.xml (from Step 3a)

OR manually enter (if using Option 2 in Step 3a):
- IdP sign-in URL: https://accounts.google.com/o/saml2/idp?idpid=<your-id>
- IdP issuer URL: https://accounts.google.com/o/saml2?idpid=<your-id>
- IdP certificate: <paste certificate from G-Suite>

Click: Next → Review and confirm
Type: ACCEPT → Change identity source

⚠️  WARNING: This disconnects any existing users in AWS Managed directory
```

**Time**: 10 minutes
**Result**: G-Suite is now the identity source for AWS IAM Identity Center

---

## Phase 3: Databricks Application in IAM Identity Center (One-Time)

### Step 5: Add Databricks as a Custom SAML Application

```
AWS Console → IAM Identity Center → Applications → Add application

Choose: I have an application I want to set up → SAML 2.0

Application properties:
- Display name: Databricks Production (or Dev/Staging based on environment)
- Description: Databricks workspace with SCIM provisioning
- Application start URL: https://<your-workspace-url>.cloud.databricks.com (optional)
- Relay state: (leave blank)

Click: Next
```

### Step 6: Configure SAML Trust with Databricks

```
Application ACS URL:
  https://accounts.cloud.databricks.com/login/callback

Application SAML audience:
  https://accounts.cloud.databricks.com

Default relay state: (leave blank)
```

### Step 7: Configure Attribute Mappings

```
IAM Identity Center → Databricks App → Attribute mappings

Subject: ${user:email}              Format: emailAddress

Additional attributes:
- Attribute:  email        → Value: ${user:email}
- Attribute:  given_name   → Value: ${user:givenName}
- Attribute:  family_name  → Value: ${user:familyName}

Click: Save changes
```

**Time**: 5 minutes
**Result**: Databricks SAML application configured in IAM Identity Center

---

## Phase 4: Terraform Automation (Run After Manual Steps)

### Step 8: Deploy Terraform Module

Once the above manual steps are complete, run Terraform:

```bash
cd /path/to/databricks_aws_tf_setup/dbx-aws-tf-dev

# Uncomment the identity_center module in main.tf
terraform plan
terraform apply
```

**What Terraform Creates**:
- ✅ Databricks service principal for SCIM
- ✅ OAuth token (1-year lifetime)
- ✅ Databricks groups (data_engineers, data_analysts, workspace_admins)
- ✅ Unity Catalog permissions (group-based access control)

**What Terraform CANNOT Create** (requires manual console steps):
- ❌ IAM Identity Center instance enablement
- ❌ External IdP (G-Suite) configuration
- ❌ SAML application provisioning settings
- ❌ Attribute mappings in IAM Identity Center
- ❌ User/group assignments to applications

---

## Phase 5: SCIM Provisioning Configuration (Manual Console Steps)

### Step 9: Enable Automatic Provisioning in IAM Identity Center

```
AWS Console → IAM Identity Center → Applications → Databricks Production

Actions → Edit configuration

Provisioning:
- Enable: Automatic provisioning

Configuration:
- SCIM endpoint:     https://accounts.cloud.databricks.com/api/2.0/preview/scim/v2
- Access token:      <from Terraform output: terraform output -raw scim_token>
- Authentication:    Bearer token

Enable operations:
✅ Create users
✅ Update user attributes
✅ Deactivate users
✅ Sync groups (optional - for group push)

Click: Test connection → Save
```

**Retrieve SCIM Token**:
```bash
# Run this command after terraform apply
terraform output -raw scim_token

# Copy the output token to IAM Identity Center provisioning config
```

**Time**: 3 minutes
**Result**: SCIM provisioning enabled, IAM Identity Center can now sync users to Databricks

---

## Phase 6: Assign Users and Test (Manual Console Steps)

### Step 10: Assign Users to Databricks Application

```
AWS Console → IAM Identity Center → Applications → Databricks Production → Assign users

Option A - Assign Individual Users:
1. Click: Assign users
2. Search: skyler@entrada.ai
3. Select user → Click: Assign users

Option B - Assign Groups (Recommended):
1. First create groups in IAM Identity Center:
   - Settings → Groups → Create group
   - Name: data_engineers
   - Add members: alice@entrada.ai, bob@entrada.ai

2. Assign group to Databricks app:
   - Applications → Databricks → Assign users
   - Groups tab → Select: data_engineers → Assign

Repeat for: data_analysts, workspace_admins groups
```

### Step 11: Test SCIM Provisioning

```
1. Wait 30-60 seconds after assignment
2. Check Databricks Account Console:
   - Go to: https://accounts.cloud.databricks.com
   - User management → Verify user appears
   - Group memberships → Verify correct groups

3. Test SSO Login:
   - Go to: https://<your-workspace-url>.cloud.databricks.com
   - Click: Sign in with SSO
   - Should redirect to G-Suite → Authenticate → Redirect back to Databricks
   - Should be logged in automatically

4. Verify Permissions:
   - In Databricks workspace: Catalog → main
   - Should see: Bronze, Silver, Gold schemas (if created)
   - data_engineers: Can create tables, write data
   - data_analysts: Can only SELECT (read-only)
```

**Time**: 5 minutes
**Result**: Users can SSO into Databricks, group memberships synced, permissions working

---

## Phase 7: Configure Group Sync from G-Suite (Optional)

### Step 12: Map G-Suite Groups to IAM Identity Center Groups

If you want G-Suite groups to automatically map to Databricks groups:

#### Option A: SCIM Provisioning from G-Suite (Requires G-Suite Enterprise)

```
G-Suite Admin Console → Directory → Groups → Create groups:
- data-engineers@entrada.ai
- data-analysts@entrada.ai
- workspace-admins@entrada.ai

G-Suite Enterprise: Can provision groups to IAM Identity Center via SCIM
(Requires additional G-Suite configuration)
```

#### Option B: Manual Group Mapping (Simpler, Works with G-Suite Basic)

```
AWS IAM Identity Center → Groups → Create groups:
- data_engineers
- data_analysts
- workspace_admins

Add users to IAM Identity Center groups based on G-Suite group membership:
- Manually add users to IAM Identity Center groups
- Or use AWS CLI/API to automate based on G-Suite API queries

IAM Identity Center will then push these groups to Databricks via SCIM
```

#### Option C: Just-In-Time (JIT) Group Provisioning via SAML

```
G-Suite Admin Console → Apps → AWS IAM Identity Center → Attributes

Add group membership attribute:
- Google Directory Attribute: Group membership
- App Attribute: groups
- Category: Group membership

AWS IAM Identity Center will create groups on-demand based on SAML assertion
(Groups auto-created in IAM Identity Center when user logs in)
```

**Recommended**: Start with Option B (manual) for simplicity, migrate to Option A/C if needed

---

## Maintenance and Operations

### Token Rotation (Annual)

```bash
# After ~11 months, rotate SCIM token:

1. In Terraform, trigger token recreation:
   terraform apply -replace="module.identity_center.databricks_oauthtoken.scim"

2. Get new token:
   terraform output -raw scim_token

3. Update in IAM Identity Center:
   Applications → Databricks → Edit configuration → Provisioning
   → Access token: <paste new token> → Save

4. Test connection to verify
```

### User Lifecycle

**New User**:
1. Add to G-Suite → Automatic SSO access
2. Assign to Databricks app in IAM Identity Center → SCIM provisions to Databricks
3. Add to IAM Identity Center group → Auto-syncs to Databricks group
4. User inherits Unity Catalog permissions from group

**Offboard User**:
1. Remove from G-Suite → SSO disabled
2. Remove from IAM Identity Center app → SCIM deactivates in Databricks
3. User loses all Databricks access immediately

### Troubleshooting

**User not appearing in Databricks**:
1. Check IAM Identity Center → Applications → Databricks → Assignments
2. Check IAM Identity Center → Applications → Databricks → Provisioning → Audit log
3. Check Databricks Account Console → User management → Activity log
4. Verify SCIM token not expired (test connection in IAM Identity Center)

**SSO not working**:
1. Verify G-Suite SAML app is enabled
2. Check SAML metadata is up-to-date in both systems
3. Test with SAML tracer browser extension
4. Check IAM Identity Center → Dashboard → Sign-in activity

---

## Summary: Manual vs Automated Steps

### One-Time Manual Steps (Cannot be Automated) - ~30 minutes
1. ✅ Enable AWS IAM Identity Center
2. ✅ Configure G-Suite as external IdP (SAML)
3. ✅ Create Databricks SAML application in IAM Identity Center
4. ✅ Enable SCIM provisioning in IAM Identity Center console
5. ✅ Assign users/groups to Databricks application

### Terraform-Managed (Fully Automated) - ~2 minutes
1. ✅ Databricks service principal creation
2. ✅ OAuth token generation (rotatable)
3. ✅ Databricks group creation
4. ✅ Unity Catalog permissions (group-based)
5. ✅ All infrastructure as code

### Ongoing Manual Operations (Lightweight)
- User assignments to Databricks app (~1 minute per user)
- Group assignments (~1 minute per group)
- SCIM token rotation (annual, ~2 minutes)

---

## Next Steps

After completing this setup:

1. **Test with 2-3 users** before rolling out organization-wide
2. **Document your specific configuration** (workspace URLs, group names, etc.)
3. **Create runbooks** for common scenarios (new hire, termination, role change)
4. **Set calendar reminders** for annual SCIM token rotation
5. **Monitor SCIM audit logs** for provisioning failures

---

**Questions?** See `IDENTITY_MANAGEMENT_STRATEGY.md` for detailed architecture and decision rationale.
