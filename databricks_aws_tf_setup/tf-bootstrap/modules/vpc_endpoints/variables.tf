variable "vpc_id"            { type = string }
variable "subnet_ids"        { type = list(string) }
variable "sg_id"             { type = string }
variable "route_table_ids" {
  type    = list(string)
  default = []
}
variable "aws_region"        { type = string }
variable "relay_service_name" {
  type    = string
  default = null
}
variable "workspace_service_name" {
  type    = string
  default = null
}
# ENTERPRISE-ONLY
variable "enable_backend_pl" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
