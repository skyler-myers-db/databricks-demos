output "bucket_name" {
  description = "Name of the Unity Catalog storage bucket"
  value       = aws_s3_bucket.unity_catalog.id
}

output "bucket_arn" {
  description = "ARN of the Unity Catalog storage bucket"
  value       = aws_s3_bucket.unity_catalog.arn
}

output "bucket_region" {
  description = "AWS region of the Unity Catalog storage bucket"
  value       = aws_s3_bucket.unity_catalog.region
}
