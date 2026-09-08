resource "aws_ecr_repository" "app" {
  #checkov:skip=CKV_AWS_136: The approved cost-aware design uses ECR-managed AES256 encryption.
  name                 = "${local.project}-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}
