variable "project_name"           { type = string }
variable "vpc_cidr"               { type = string }
variable "private_subnet_cidrs"   { type = list(string) }
variable "public_subnet_cidrs"    { type = list(string) }
variable "endpoint_subnet_cidrs"  { type = list(string) }
variable "tags" {
  type    = map(string)
  default = {}
}
