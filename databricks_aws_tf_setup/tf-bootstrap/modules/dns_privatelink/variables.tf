variable "vpc_id"                      { type = string }
variable "domain_name"                 { type = string } # e.g., privatelink.internal
variable "workspace_deployment_fqdn"   { type = string } # <deployment>.cloud.databricks.com
variable "workspace_dp_cname"          { type = string } # dbc-dp-<workspace-id>.cloud.databricks.com
variable "vpce_ips"                    { type = list(string) }
