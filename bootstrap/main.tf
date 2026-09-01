data "aws_caller_identity" "current" {}

locals {
  bucket_name = "soat-oficina-tfstate-${data.aws_caller_identity.current.account_id}-us-east-1"
}

resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_18: A separate access-log bucket is outside the approved short-lived academic design.
  #checkov:skip=CKV_AWS_144: The approved architecture is single-region in us-east-1 and does not replicate state cross-region.
  #checkov:skip=CKV_AWS_145: The approved bootstrap contract requires S3-managed AES256 encryption.
  #checkov:skip=CKV2_AWS_61: State versions are retained without automated expiration for recovery throughout Phase 3.
  #checkov:skip=CKV2_AWS_62: State object event notifications are outside the approved bootstrap contract.
  bucket = local.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
