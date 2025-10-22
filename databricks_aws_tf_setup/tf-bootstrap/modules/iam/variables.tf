variable "project_name"   { type = string }
variable "s3_root_arn"    { type = string }
variable "s3_logs_arn"    { type = string }
variable "kms_key_arn"    { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
