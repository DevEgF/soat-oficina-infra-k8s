ephemeral "random_password" "jwt" {
  length  = 64
  special = true
}

resource "aws_secretsmanager_secret" "jwt" {
  #checkov:skip=CKV_AWS_149: The approved cost-aware design uses the AWS managed Secrets Manager key.
  #checkov:skip=CKV2_AWS_57: Automatic rotation for the shared academic JWT key is outside the approved Phase 3 lifecycle.
  name                    = "${local.project}/shared/jwt"
  description             = "Shared HS256 JWT signing key for hml and prod"
  recovery_window_in_days = 0
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id                = aws_secretsmanager_secret.jwt.id
  secret_string_wo         = jsonencode({ value = ephemeral.random_password.jwt.result })
  secret_string_wo_version = 1
}
