# Bundles — Platform Artifacts

This Databricks Asset Bundle defines **workspace objects** you typically want to version alongside code. It intentionally avoids infra: VPC/S3/IAM/MWS are Terraform-managed.

Run locally:
```
export DATABRICKS_HOST="https://<workspace-url>"
export DATABRICKS_TOKEN="<pat-or-oauth>"
databricks bundle validate
databricks bundle deploy
```
Supported resource types and syntax: see docs. citeturn8view0
