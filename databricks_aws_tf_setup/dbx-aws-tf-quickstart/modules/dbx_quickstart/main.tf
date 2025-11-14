resource "aws_organizations_account" "this" {
  name                       = "acc-${var.project_name}"
  email                      = var.aws_acc_email
  close_on_deletion          = true
  create_govcloud            = false
  iam_user_access_to_billing = "ALLOW"
  parent_id                  = var.parent_ou_id
  role_name                  = var.aws_acc_switch_role

  lifecycle {
    prevent_destroy = false
  }
}
