data "aws_iam_policy_document" "app_pod_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_pod" {
  name               = "${local.project}-app-pod"
  assume_role_policy = data.aws_iam_policy_document.app_pod_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "app_jwt_secret" {
  statement {
    sid       = "ReadSharedJwtSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.jwt.arn]
  }
}

resource "aws_iam_role_policy" "app_jwt_secret" {
  name   = "read-shared-jwt-secret"
  role   = aws_iam_role.app_pod.id
  policy = data.aws_iam_policy_document.app_jwt_secret.json
}

resource "aws_eks_pod_identity_association" "app" {
  for_each = local.environments

  cluster_name    = module.eks.cluster_name
  namespace       = each.value
  service_account = "oficina-app"
  role_arn        = aws_iam_role.app_pod.arn
}
