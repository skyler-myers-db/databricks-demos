variable "root_bucket_name" { type = string }
variable "log_bucket_name"  { type = string }
variable "kms_key_alias"    { type = string }
variable "vpc_id"           { type = string }
variable "vpce_ids"         { type = list(string) }
variable "tags" {
  type    = map(string)
  default = {}
}
