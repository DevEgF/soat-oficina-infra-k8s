output "state_bucket_name" {
  description = "Encrypted S3 bucket used by the Phase 3 Terraform states."
  value       = aws_s3_bucket.state.id
}
