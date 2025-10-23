output "account_id" {
  description = "The AWS account ID"
  value       = aws_organizations_account.dev.id
}

output "account_arn" {
  description = "The ARN of the account"
  value       = aws_organizations_account.dev.arn
}

output "role_name" {
  description = "The role name that can be assumed to access this account"
  value       = aws_organizations_account.dev.role_name
}
