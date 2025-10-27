# Terraform Code Style Guide

This document defines the coding standards and best practices for this Terraform project.

## File Organization

### Root Module Structure
```
.
├── main.tf           # Primary resource definitions
├── variables.tf      # Input variable declarations
├── outputs.tf        # Output value declarations
├── providers.tf      # Provider configurations
├── versions.tf       # Provider version constraints
├── terraform.tfvars  # Variable values (gitignored)
└── modules/          # Reusable module definitions
```

### Module Structure
```
modules/<module-name>/
├── main.tf           # Resource definitions
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── versions.tf       # Provider requirements
└── README.md         # Module documentation (optional)
```

## Naming Conventions

### Resources
- Use **snake_case** for resource names
- Use descriptive, purpose-driven names
- Prefix with resource type when helpful for clarity

**Good:**
```hcl
resource "aws_s3_bucket" "unity_catalog_storage" { ... }
resource "databricks_metastore" "this" { ... }
```

**Avoid:**
```hcl
resource "aws_s3_bucket" "bucket1" { ... }
resource "databricks_metastore" "ms" { ... }
```

### Variables
- Use **snake_case** for variable names
- Group related variables together
- Use descriptive names that indicate purpose

**Good:**
```hcl
variable "databricks_account_id" { ... }
variable "unity_catalog_storage_bucket_name" { ... }
```

**Avoid:**
```hcl
variable "dbx_acc_id" { ... }
variable "uc_bucket" { ... }
```

### Outputs
- Use **snake_case** for output names
- Include resource type in name when helpful
- Group related outputs together

**Good:**
```hcl
output "workspace_url" { ... }
output "metastore_id" { ... }
```

### Modules
- Use **lowercase with hyphens** for module directory names
- Prefix with cloud provider for provider-specific modules
- Use descriptive names indicating module purpose

**Good:**
```
modules/aws-vpc/
modules/databricks-workspace/
modules/unity-catalog-storage-credential/
```

**Avoid:**
```
modules/VPC/
modules/dbx_ws/
```

## Code Formatting

### Indentation
- Use **2 spaces** for indentation (no tabs)
- Align equals signs for readability in blocks

```hcl
variable "example" {
  type        = string
  description = "Example variable"
  default     = "value"
}
```

### Line Length
- Maximum **120 characters** per line
- Break long lines logically (at operators, commas, or brackets)

### Blank Lines
- One blank line between top-level blocks
- Two blank lines between major sections
- No blank lines within resource blocks unless for readability

### Comments
- Use `#` for single-line comments
- Use `/* */` for multi-line block comments
- Add comments above the code they describe
- Use comment headers for major sections

```hcl
# ============================================================================
# SECTION NAME
# ============================================================================
# Purpose: Brief description of this section
# Dependencies: List key dependencies
# ============================================================================
```

## Best Practices

### Variables
1. **Always include descriptions** for all variables
2. **Use type constraints** to catch errors early
3. **Provide sensible defaults** when appropriate
4. **Mark sensitive variables** with `sensitive = true`
5. **Validate inputs** using validation blocks

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

### Outputs
1. **Include descriptions** for all outputs
2. **Mark sensitive outputs** with `sensitive = true`
3. **Group related outputs** together
4. **Use meaningful output names** that indicate their purpose

### Resources
1. **Use explicit dependencies** with `depends_on` when necessary
2. **Tag all resources** consistently for cost tracking and organization
3. **Use locals** for computed values used multiple times
4. **Avoid hardcoded values** - use variables or data sources

### Modules
1. **Keep modules focused** on a single responsibility
2. **Document inputs and outputs** in module README
3. **Use semantic versioning** for module versions
4. **Test modules** independently

### Documentation
1. **Inline comments** for complex logic or non-obvious decisions
2. **Section headers** to organize large files
3. **README files** for modules explaining purpose and usage
4. **Examples** demonstrating module usage

## Git Practices

### Commit Messages
- Use conventional commit format: `type(scope): message`
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- Keep first line under 72 characters
- Provide detailed description in commit body

**Example:**
```
feat(networking): add VPC endpoints for S3 and EC2

- Adds Gateway endpoint for S3 (cost-free)
- Adds Interface endpoint for EC2 (required for cluster provisioning)
- Configures security groups and route table associations
```

### Branch Strategy
- `main` - production-ready code
- `develop` - integration branch
- `feature/*` - feature branches
- `fix/*` - bug fix branches

## Security Best Practices

1. **Never commit secrets** to version control
2. **Use `.gitignore`** for sensitive files (`terraform.tfvars`, `*.tfstate`)
3. **Encrypt remote state** with encryption at rest
4. **Use IAM roles** instead of access keys where possible
5. **Apply least privilege** principle to all IAM policies
6. **Enable MFA** for sensitive operations

## Performance Optimization

1. **Use data sources** instead of outputs when possible
2. **Minimize provider API calls** with careful dependency management
3. **Use `count` and `for_each`** instead of multiple similar resources
4. **Enable parallel operations** by avoiding unnecessary dependencies
5. **Use remote state** for large infrastructures

## Testing

1. **Validate syntax:** `terraform validate`
2. **Format code:** `terraform fmt -recursive`
3. **Plan before apply:** Always review `terraform plan` output
4. **Use workspaces** for multiple environments
5. **Test in non-production** before production deployment
