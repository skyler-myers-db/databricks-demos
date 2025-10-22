variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

# Databricks account-level OAuth
variable "databricks_account_id" {
  type = string
}

variable "databricks_client_id" {
  type = string
}

variable "databricks_client_secret" {
  type      = string
  sensitive = true
}

# Workspace parameters
variable "workspace_name" {
  type = string
}

variable "workspace_admin_group" {
  type    = string
  default = "admins"
}

# Networking
variable "vpc_cidr" {
  type = string
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "endpoint_subnet_cidrs" {
  type    = list(string)
  default = []
} # for VPCEs (recommended)

# Storage
variable "root_bucket_name" {
  type = string
}

variable "log_bucket_name" {
  type = string
}

variable "kms_key_alias" {
  type    = string
  default = "alias/databricks-root"
}

# Feature toggles
variable "enable_privatelink_backend" {
  type    = bool
  default = false
} # ENTERPRISE-ONLY

variable "databricks_relay_service_name" {
  type    = string
  default = null
} # ENTERPRISE-ONLY; populate when enable_privatelink_backend = true

variable "databricks_workspace_service_name" {
  type    = string
  default = null
} # ENTERPRISE-ONLY; populate when enable_privatelink_backend = true

variable "enable_privatelink_frontend" {
  type    = bool
  default = false
} # ENTERPRISE-ONLY

variable "enable_system_tables" {
  type    = bool
  default = true
}

variable "enable_flow_logs" {
  type    = bool
  default = true
}

variable "enable_s3_account_block" {
  type    = bool
  default = true
}

variable "enable_workspace_resources" {
  type    = bool
  default = false
}

# Front-end PL DNS
variable "pl_phz_domain" {
  type    = string
  default = "privatelink.internal"
} # private zone to host A/CNAME

variable "workspace_deployment_name" {
  type    = string
  default = ""
} # e.g., oregon / nvirginia per docs

variable "workspace_dp_cname" {
  type    = string
  default = ""
} # dbc-dp-<workspace-id>.cloud.databricks.com (filled post-create)

variable "workspace_url" {
  type    = string
  default = ""
} # <deployment>.cloud.databricks.com (filled post-create)

variable "frontend_vpce_ips" {
  type    = list(string)
  default = []
} # A record to VPCE private IPs per docs

# Federation sample
variable "federation_example_enabled" {
  type    = bool
  default = false
}

variable "federation_conn_type" {
  type    = string
  default = "POSTGRESQL"
}

variable "federation_conn_host" {
  type    = string
  default = ""
}

variable "federation_conn_port" {
  type    = number
  default = 5432
}

variable "federation_conn_user" {
  type    = string
  default = ""
}

variable "federation_conn_password" {
  type      = string
  default   = ""
  sensitive = true
} # NOTE: Sensitive; state will contain ciphertext metadata.

variable "federation_database" {
  type    = string
  default = ""
}
