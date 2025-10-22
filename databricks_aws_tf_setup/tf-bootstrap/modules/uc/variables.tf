variable "region"                  { type = string }
variable "metastore_storage_root"  { type = string }
variable "cross_account_role_arn"  { type = string }
variable "workspace_id"            { type = string }
variable "enable_system_tables"    { type = bool }
variable "federation_example_enabled" { type = bool }
variable "federation_conn" {
  type = object({
    type     = string
    host     = string
    port     = number
    user     = string
    password = string
    database = string
  })
}
variable "tags" {
  type    = map(string)
  default = {}
}
