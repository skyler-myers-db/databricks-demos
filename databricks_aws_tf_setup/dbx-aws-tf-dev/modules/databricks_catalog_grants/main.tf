/**
 * Databricks Unity Catalog Grants Module
 *
 * Purpose:
 * Configures permissions on Unity Catalog catalogs, schemas, and tables.
 * Grants access to service principals and groups for data platform operations.
 *
 * Sandbox Environment Strategy:
 * - Broad permissions for experimentation and learning
 * - Service principals get ALL PRIVILEGES for automation
 * - Data engineers get full CRUD access
 * - Catalog owner gets administrative control
 *
 * Databricks Documentation:
 * https://docs.databricks.com/data-governance/unity-catalog/manage-privileges/privileges.html
 */

# ============================================================================
# CATALOG-LEVEL GRANTS
# ============================================================================

# Grant ALL PRIVILEGES to catalog owner (workspace admin user)
resource "databricks_grants" "catalog_owner" {
  catalog = var.catalog_name

  grant {
    principal  = var.catalog_owner_principal
    privileges = ["ALL_PRIVILEGES"]
  }
}

# Grant ALL PRIVILEGES to job-runner service principal (for automation)
resource "databricks_grants" "catalog_service_principal" {
  catalog = var.catalog_name

  grant {
    principal  = var.job_runner_sp_application_id
    privileges = ["ALL_PRIVILEGES"]
  }

  depends_on = [databricks_grants.catalog_owner]
}

# Grant broad permissions to data engineers group (sandbox environment)
resource "databricks_grants" "catalog_data_engineers" {
  catalog = var.catalog_name

  grant {
    principal = var.data_engineers_group_name
    privileges = [
      "USE_CATALOG",
      "USE_SCHEMA",
      "CREATE_SCHEMA",
      "CREATE_TABLE",
      "CREATE_FUNCTION",
      "CREATE_VOLUME",
      "EXECUTE"
    ]
  }

  depends_on = [databricks_grants.catalog_service_principal]
}

# ============================================================================
# DEFAULT SCHEMA-LEVEL GRANTS
# ============================================================================
# Grant permissions on the default schema created with the catalog

# Owner gets ALL PRIVILEGES on default schema
resource "databricks_grants" "default_schema_owner" {
  schema = "${var.catalog_name}.default"

  grant {
    principal  = var.catalog_owner_principal
    privileges = ["ALL_PRIVILEGES"]
  }

  depends_on = [databricks_grants.catalog_owner]
}

# Service principal gets ALL PRIVILEGES on default schema
resource "databricks_grants" "default_schema_service_principal" {
  schema = "${var.catalog_name}.default"

  grant {
    principal  = var.job_runner_sp_application_id
    privileges = ["ALL_PRIVILEGES"]
  }

  depends_on = [databricks_grants.default_schema_owner]
}

# Data engineers get broad permissions on default schema
resource "databricks_grants" "default_schema_data_engineers" {
  schema = "${var.catalog_name}.default"

  grant {
    principal = var.data_engineers_group_name
    privileges = [
      "USE_SCHEMA",
      "SELECT",
      "MODIFY",
      "CREATE_TABLE",
      "CREATE_FUNCTION",
      "CREATE_VOLUME",
      "EXECUTE"
    ]
  }

  depends_on = [databricks_grants.default_schema_service_principal]
}

# ============================================================================
# FUTURE TABLES GRANTS (applies to all tables created in future)
# ============================================================================
# This ensures any table created in the default schema inherits permissions

# Grant permissions on future tables in the default schema
# Format for future grants: <catalog>.<schema>.tables (no specific table name)



# ============================================================================
# OUTPUTS
# ============================================================================

output "catalog_grants_summary" {
  description = "Summary of catalog grants configured"
  value = {
    catalog = var.catalog_name
    grants = {
      owner = {
        principal  = var.catalog_owner_principal
        privileges = "ALL_PRIVILEGES (catalog + default schema)"
      }
      service_principal = {
        principal  = var.job_runner_sp_application_id
        privileges = "ALL_PRIVILEGES (catalog + default schema)"
      }
      data_engineers = {
        principal = var.data_engineers_group_name
        privileges = join(", ", [
          "USE_CATALOG",
          "USE_SCHEMA",
          "CREATE_SCHEMA",
          "CREATE_TABLE",
          "SELECT",
          "MODIFY"
        ])
      }
    }
    note = "Data engineers can create schemas, tables, and have full CRUD access in sandbox environment"
  }
}

output "catalog_name" {
  description = "Name of the catalog with grants configured"
  value       = var.catalog_name
}

output "default_schema_name" {
  description = "Name of the default schema with grants configured"
  value       = "${var.catalog_name}.default"
}

output "principals_with_access" {
  description = "List of principals with access to the catalog"
  value = [
    var.catalog_owner_principal,
    var.job_runner_sp_application_id,
    var.data_engineers_group_name
  ]
}
