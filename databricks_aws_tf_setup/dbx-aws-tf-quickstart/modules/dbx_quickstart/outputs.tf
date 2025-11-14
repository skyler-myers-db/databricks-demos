output "aws_acc_id" {
  description = "The AWS account ID"
  value       = aws_organizations_account.this.id
}

output "aws_acc_arn" {
  description = "The ARN of the account"
  value       = aws_organizations_account.this.arn
}
