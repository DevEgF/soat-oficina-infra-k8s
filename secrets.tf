ephemeral "random_password" "jwt" {
  length  = 64
  special = false
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
  secret_string_wo_version = 2
}

locals {
  staff_roles = toset(["master", "admin", "attendant", "technician", "warehouse"])
  staff_password_keys = {
    for pair in setproduct(local.environments, local.staff_roles) :
    "${pair[0]}:${pair[1]}" => { environment = pair[0], role = pair[1] }
  }
}

ephemeral "random_password" "staff" {
  for_each = local.staff_password_keys
  length   = 48
  special  = false
}

resource "aws_secretsmanager_secret" "staff" {
  #checkov:skip=CKV_AWS_149: Preserve the approved ephemeral stack's AWS-managed Secrets Manager encryption.
  #checkov:skip=CKV2_AWS_57: Staff passwords are rotated explicitly together with application restart during the short academic lifecycle.
  for_each = local.environments

  name                    = "${local.project}/${each.value}/staff"
  description             = "Application staff login configuration for ${each.value}"
  recovery_window_in_days = 0
  tags                    = merge(local.common_tags, { Environment = each.value })
}

resource "aws_secretsmanager_secret_version" "staff" {
  for_each = local.environments

  secret_id = aws_secretsmanager_secret.staff[each.value].id
  secret_string_wo = jsonencode({
    for role in local.staff_roles : role => ephemeral.random_password.staff["${each.value}:${role}"].result
  })
  secret_string_wo_version = 1
}
