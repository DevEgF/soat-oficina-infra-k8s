data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  github_repositories = toset([
    "soat-oficina-infra-k8s",
    "soat-oficina-infra-db",
    "soat-oficina-auth",
    "soat-oficina-app",
  ])
  github_deploy_roles = {
    for pair in setproduct(local.github_repositories, local.environments) :
    "${pair[0]}:${pair[1]}" => {
      repository  = pair[0]
      environment = pair[1]
    }
  }
  state_bucket_name        = "${local.project}-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  state_bucket_arn         = "arn:${data.aws_partition.current.partition}:s3:::${local.state_bucket_name}"
  github_oidc_provider_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"

  state_actions = [
    "s3:GetBucketLocation",
    "s3:ListBucket",
  ]
  state_object_actions = [
    "s3:DeleteObject",
    "s3:GetObject",
    "s3:PutObject",
  ]

  foundation_actions = [
    "autoscaling:AttachLoadBalancerTargetGroups",
    "autoscaling:DescribeAutoScalingGroups",
    "autoscaling:DetachLoadBalancerTargetGroups",
    "cloudwatch:DeleteAlarms",
    "cloudwatch:DeleteDashboards",
    "cloudwatch:GetDashboard",
    "cloudwatch:DescribeAlarms",
    "cloudwatch:ListTagsForResource",
    "cloudwatch:PutDashboard",
    "cloudwatch:PutMetricAlarm",
    "ec2:AssociateRouteTable",
    "ec2:AttachInternetGateway",
    "ec2:AuthorizeSecurityGroupEgress",
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:CreateInternetGateway",
    "ec2:CreateLaunchTemplate",
    "ec2:CreateLaunchTemplateVersion",
    "ec2:CreateNetworkAclEntry",
    "ec2:CreateRoute",
    "ec2:CreateRouteTable",
    "ec2:CreateSecurityGroup",
    "ec2:CreateSubnet",
    "ec2:CreateTags",
    "ec2:CreateVpc",
    "ec2:CreateVpcEndpoint",
    "ec2:DeleteInternetGateway",
    "ec2:DeleteLaunchTemplate",
    "ec2:DeleteLaunchTemplateVersions",
    "ec2:DeleteNetworkAclEntry",
    "ec2:DeleteRoute",
    "ec2:DeleteRouteTable",
    "ec2:DeleteSecurityGroup",
    "ec2:DeleteSubnet",
    "ec2:DeleteTags",
    "ec2:DeleteVpc",
    "ec2:DeleteVpcEndpoints",
    "ec2:DescribeAddresses",
    "ec2:DescribeAvailabilityZones",
    "ec2:DescribeInternetGateways",
    "ec2:DescribeLaunchTemplates",
    "ec2:DescribeLaunchTemplateVersions",
    "ec2:DescribeNatGateways",
    "ec2:DescribeNetworkAcls",
    "ec2:DescribeNetworkInterfaces",
    "ec2:DescribePrefixLists",
    "ec2:DescribeRouteTables",
    "ec2:DescribeSecurityGroupRules",
    "ec2:DescribeSecurityGroups",
    "ec2:DescribeSubnets",
    "ec2:DescribeTags",
    "ec2:DescribeVpcEndpointServices",
    "ec2:DescribeVpcEndpoints",
    "ec2:DescribeVpcAttribute",
    "ec2:DescribeVpcs",
    "ec2:DetachInternetGateway",
    "ec2:DisassociateRouteTable",
    "ec2:ModifyLaunchTemplate",
    "ec2:ModifySubnetAttribute",
    "ec2:ModifyVpcAttribute",
    "ec2:ModifyVpcEndpoint",
    "ec2:ReplaceRoute",
    "ec2:RevokeSecurityGroupEgress",
    "ec2:RevokeSecurityGroupIngress",
    "ecr:CreateRepository",
    "ecr:DeleteLifecyclePolicy",
    "ecr:DeleteRepository",
    "ecr:DescribeRepositories",
    "ecr:GetLifecyclePolicy",
    "ecr:ListTagsForResource",
    "ecr:PutLifecyclePolicy",
    "ecr:PutImageScanningConfiguration",
    "ecr:PutImageTagMutability",
    "ecr:TagResource",
    "ecr:UntagResource",
    "eks:AssociateAccessPolicy",
    "eks:CreateAccessEntry",
    "eks:CreateAddon",
    "eks:CreateCluster",
    "eks:CreateNodegroup",
    "eks:CreatePodIdentityAssociation",
    "eks:DeleteAccessEntry",
    "eks:DeleteAddon",
    "eks:DeleteCluster",
    "eks:DeleteNodegroup",
    "eks:DeletePodIdentityAssociation",
    "eks:DescribeAccessEntry",
    "eks:DescribeAddon",
    "eks:DescribeAddonVersions",
    "eks:DescribeCluster",
    "eks:DescribeNodegroup",
    "eks:DescribePodIdentityAssociation",
    "eks:DisassociateAccessPolicy",
    "eks:ListAccessEntries",
    "eks:ListAssociatedAccessPolicies",
    "eks:ListPodIdentityAssociations",
    "eks:ListTagsForResource",
    "eks:TagResource",
    "eks:UntagResource",
    "eks:UpdateAddon",
    "eks:UpdateClusterConfig",
    "eks:UpdateClusterVersion",
    "eks:UpdateNodegroupConfig",
    "elasticloadbalancing:AddTags",
    "elasticloadbalancing:CreateListener",
    "elasticloadbalancing:CreateLoadBalancer",
    "elasticloadbalancing:CreateTargetGroup",
    "elasticloadbalancing:DeleteListener",
    "elasticloadbalancing:DeleteLoadBalancer",
    "elasticloadbalancing:DeleteTargetGroup",
    "elasticloadbalancing:DescribeCapacityReservation",
    "elasticloadbalancing:DescribeListenerAttributes",
    "elasticloadbalancing:DescribeListeners",
    "elasticloadbalancing:DescribeLoadBalancerAttributes",
    "elasticloadbalancing:DescribeLoadBalancers",
    "elasticloadbalancing:DescribeTags",
    "elasticloadbalancing:DescribeTargetGroupAttributes",
    "elasticloadbalancing:DescribeTargetGroups",
    "elasticloadbalancing:ModifyLoadBalancerAttributes",
    "elasticloadbalancing:ModifyTargetGroup",
    "elasticloadbalancing:ModifyTargetGroupAttributes",
    "elasticloadbalancing:RemoveTags",
    "elasticloadbalancing:SetSecurityGroups",
    "kms:CreateAlias",
    "kms:CreateGrant",
    "kms:CreateKey",
    "kms:DeleteAlias",
    "kms:DescribeKey",
    "kms:DisableKey",
    "kms:EnableKey",
    "kms:EnableKeyRotation",
    "kms:GetKeyPolicy",
    "kms:GetKeyRotationStatus",
    "kms:ListAliases",
    "kms:ListResourceTags",
    "kms:PutKeyPolicy",
    "kms:ScheduleKeyDeletion",
    "kms:TagResource",
    "kms:UntagResource",
    "kms:UpdateAlias",
    "kms:UpdateKeyDescription",
    "logs:CreateLogGroup",
    "logs:DeleteLogGroup",
    "logs:DescribeLogGroups",
    "logs:ListTagsForResource",
    "logs:PutRetentionPolicy",
    "logs:TagResource",
    "logs:UntagResource",
    "secretsmanager:CreateSecret",
    "secretsmanager:DeleteSecret",
    "secretsmanager:DescribeSecret",
    "secretsmanager:GetResourcePolicy",
    "secretsmanager:ListSecretVersionIds",
    "secretsmanager:PutSecretValue",
    "secretsmanager:TagResource",
    "secretsmanager:UntagResource",
    "sns:CreateTopic",
    "sns:DeleteTopic",
    "sns:GetSubscriptionAttributes",
    "sns:GetTopicAttributes",
    "sns:ListTagsForResource",
    "sns:SetTopicAttributes",
    "sns:Subscribe",
    "sns:TagResource",
    "sns:Unsubscribe",
    "sns:UntagResource",
  ]

  database_actions = [
    "ec2:AuthorizeSecurityGroupEgress",
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:CreateSecurityGroup",
    "ec2:CreateTags",
    "ec2:DeleteSecurityGroup",
    "ec2:DeleteTags",
    "ec2:DescribeSecurityGroupRules",
    "ec2:DescribeSecurityGroups",
    "ec2:DescribeSubnets",
    "ec2:DescribeVpcs",
    "ec2:RevokeSecurityGroupEgress",
    "ec2:RevokeSecurityGroupIngress",
    "logs:DescribeLogGroups",
    "rds:AddTagsToResource",
    "rds:CreateDBInstance",
    "rds:CreateDBParameterGroup",
    "rds:CreateDBSnapshot",
    "rds:CreateDBSubnetGroup",
    "rds:CopyDBSnapshot",
    "rds:DeleteDBInstance",
    "rds:DeleteDBParameterGroup",
    "rds:DeleteDBSnapshot",
    "rds:DeleteDBSubnetGroup",
    "rds:DescribeDBInstances",
    "rds:DescribeDBParameterGroups",
    "rds:DescribeDBParameters",
    "rds:DescribeDBSnapshots",
    "rds:DescribeDBSubnetGroups",
    "rds:ListTagsForResource",
    "rds:ModifyDBInstance",
    "rds:ModifyDBParameterGroup",
    "rds:ModifyDBSubnetGroup",
    "rds:RemoveTagsFromResource",
    "secretsmanager:DescribeSecret",
  ]

  auth_actions = [
    "apigateway:DELETE",
    "apigateway:GET",
    "apigateway:PATCH",
    "apigateway:POST",
    "apigateway:PUT",
    "cloudwatch:DeleteAlarms",
    "cloudwatch:DeleteDashboards",
    "cloudwatch:DescribeAlarms",
    "cloudwatch:ListTagsForResource",
    "cloudwatch:PutDashboard",
    "cloudwatch:PutMetricAlarm",
    "ec2:DescribeNetworkInterfaces",
    "ec2:DescribeSecurityGroups",
    "ec2:DescribeSubnets",
    "ec2:DescribeVpcs",
    "lambda:AddPermission",
    "lambda:CreateFunction",
    "lambda:DeleteFunction",
    "lambda:GetFunction",
    "lambda:GetFunctionCodeSigningConfig",
    "lambda:GetPolicy",
    "lambda:ListTags",
    "lambda:PublishVersion",
    "lambda:RemovePermission",
    "lambda:TagResource",
    "lambda:UntagResource",
    "lambda:UpdateFunctionCode",
    "lambda:UpdateFunctionConfiguration",
    "logs:CreateLogGroup",
    "logs:DeleteLogGroup",
    "logs:DescribeLogGroups",
    "logs:ListTagsForResource",
    "logs:PutRetentionPolicy",
    "logs:TagResource",
    "logs:UntagResource",
    "synthetics:CreateCanary",
    "synthetics:DeleteCanary",
    "synthetics:GetCanary",
    "synthetics:StartCanary",
    "synthetics:StopCanary",
    "synthetics:UpdateCanary",
  ]

  app_actions = [
    "ecr:GetAuthorizationToken",
  ]
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  tags           = local.common_tags
}

resource "aws_iam_role" "github_deploy" {
  for_each = local.github_deploy_roles

  name = "${each.value.repository}-${each.value.environment}-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.github_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}@${var.github_owner_id}/${each.value.repository}@${var.github_repository_ids[each.value.repository]}:environment:${each.value.environment}"
        }
      }
    }]
  })
  max_session_duration = 3600
  tags                 = merge(local.common_tags, { Repository = each.value.repository, Environment = each.value.environment })

  depends_on = [aws_iam_openid_connect_provider.github]
}

resource "aws_iam_role_policy" "github_infra_k8s" {
  #checkov:skip=CKV_AWS_289: The approved foundation controller must manage only soat-oficina prefixed IAM resources; PassRole is separately service-constrained.
  #checkov:skip=CKV_AWS_290: Foundation write actions are enumerated; create and describe APIs without resource-level support require wildcard resources.
  #checkov:skip=CKV_AWS_355: Wildcard resources apply only to enumerated foundation actions; IAM and state resources are scoped separately.
  for_each = { for key, role in local.github_deploy_roles : key => role if role.repository == "soat-oficina-infra-k8s" }

  name = "phase-3-${each.value.repository}-${each.value.environment}"
  role = aws_iam_role.github_deploy[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "FoundationServices"
        Effect   = "Allow"
        Action   = local.foundation_actions
        Resource = "*"
      },
      {
        Sid    = "FoundationBudget"
        Effect = "Allow"
        Action = [
          "budgets:ListTagsForResource",
          "budgets:ModifyBudget",
          "budgets:TagResource",
          "budgets:UntagResource",
          "budgets:ViewBudget",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:budgets::${data.aws_caller_identity.current.account_id}:budget/${local.project}-*"
      },
      {
        Sid      = "FoundationBillingAccess"
        Effect   = "Allow"
        Action   = ["aws-portal:ModifyBilling", "aws-portal:ViewBilling"]
        Resource = "*"
      },
      {
        Sid      = "FoundationEksAmiParameter"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}::parameter/aws/service/eks/optimized-ami/*"
      },
      {
        Sid    = "FoundationIam"
        Effect = "Allow"
        Action = [
          "iam:AddClientIDToOpenIDConnectProvider",
          "iam:AttachRolePolicy",
          "iam:CreateOpenIDConnectProvider",
          "iam:CreatePolicy",
          "iam:CreatePolicyVersion",
          "iam:CreateRole",
          "iam:DeleteOpenIDConnectProvider",
          "iam:DeletePolicy",
          "iam:DeletePolicyVersion",
          "iam:DeleteRole",
          "iam:DeleteRolePolicy",
          "iam:DetachRolePolicy",
          "iam:GetOpenIDConnectProvider",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:ListPolicyVersions",
          "iam:ListRolePolicies",
          "iam:ListRoleTags",
          "iam:PutRolePolicy",
          "iam:RemoveClientIDFromOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:TagPolicy",
          "iam:TagRole",
          "iam:UntagOpenIDConnectProvider",
          "iam:UntagPolicy",
          "iam:UntagRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:UpdateOpenIDConnectProviderThumbprint",
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com",
          "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/soat-oficina-*",
          "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/soat-oficina-*",
        ]
      },
      {
        Sid      = "FoundationPassRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/soat-oficina-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = ["ec2.amazonaws.com", "eks.amazonaws.com", "pods.eks.amazonaws.com"]
          }
        }
      },
      {
        Sid      = "TerraformStateBucket"
        Effect   = "Allow"
        Action   = local.state_actions
        Resource = local.state_bucket_arn
        Condition = {
          StringLike = { "s3:prefix" = ["infra-k8s/*"] }
        }
      },
      {
        Sid      = "TerraformStateObjects"
        Effect   = "Allow"
        Action   = local.state_object_actions
        Resource = "${local.state_bucket_arn}/infra-k8s/*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "github_infra_db" {
  #checkov:skip=CKV_AWS_290: Database write actions are enumerated; provisioning APIs without resource-level support require wildcard resources.
  #checkov:skip=CKV_AWS_355: Wildcard resources apply only to enumerated database actions; IAM and state resources are scoped separately.
  for_each = { for key, role in local.github_deploy_roles : key => role if role.repository == "soat-oficina-infra-db" }

  name = "phase-3-${each.value.repository}-${each.value.environment}"
  role = aws_iam_role.github_deploy[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DatabaseServices"
        Effect   = "Allow"
        Action   = local.database_actions
        Resource = "*"
      },
      {
        Sid      = "RdsServiceLinkedRole"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"
        Condition = {
          StringEquals = { "iam:AWSServiceName" = "rds.amazonaws.com" }
        }
      },
      {
        Sid      = "RdsServiceLinkedRoleLifecycle"
        Effect   = "Allow"
        Action   = ["iam:GetRole", "iam:TagRole", "iam:UntagRole", "iam:DeleteServiceLinkedRole", "iam:GetServiceLinkedRoleDeletionStatus"]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"
      },
      {
        Sid    = "DatabaseLogGroup"
        Effect = "Allow"
        Action = [
          "logs:AssociateKmsKey",
          "logs:TagResource",
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DisassociateKmsKey",
          "logs:PutRetentionPolicy",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/rds/instance/soat-oficina-db/postgresql:*"
      },
      {
        Sid    = "DatabaseLogGroupTags"
        Effect = "Allow"
        Action = [
          "logs:ListTagsForResource",
          "logs:TagResource",
          "logs:UntagResource",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/rds/instance/soat-oficina-db/postgresql"
      },
      {
        Sid    = "DatabaseAlarms"
        Effect = "Allow"
        Action = [
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListTagsForResource",
          "cloudwatch:ListTagsForResource",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource",
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:soat-oficina-db-high-connections",
          "arn:${data.aws_partition.current.partition}:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:soat-oficina-db-high-cpu",
          "arn:${data.aws_partition.current.partition}:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:soat-oficina-db-low-storage",
        ]
      },
      {
        Sid      = "DatabaseKmsCreate"
        Effect   = "Allow"
        Action   = ["kms:CreateKey", "kms:TagResource"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Component" = "infra-db"
            "aws:RequestTag/Project"   = local.project
          }
          "ForAllValues:StringEquals" = {
            "aws:TagKeys" = [
              "Component",
              "CreatedBy",
              "GenerationModel",
              "ManagedBy",
              "Phase",
              "Project",
            ]
          }
        }
      },
      {
        Sid      = "DatabaseKmsDiscovery"
        Effect   = "Allow"
        Action   = ["kms:ListAliases"]
        Resource = "*"
      },
      {
        Sid    = "DatabaseKmsKeyLifecycle"
        Effect = "Allow"
        Action = [
          "kms:DescribeKey",
          "kms:EnableKeyRotation",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus",
          "kms:ListGrants",
          "kms:ListResourceTags",
          "kms:PutKeyPolicy",
          "kms:RevokeGrant",
          "kms:ScheduleKeyDeletion",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:UpdateKeyDescription",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Component" = "infra-db"
            "aws:ResourceTag/Project"   = local.project
          }
        }
      },
      {
        Sid      = "DatabaseKmsGrant"
        Effect   = "Allow"
        Action   = ["kms:CreateGrant"]
        Resource = "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
          StringEquals = {
            "aws:ResourceTag/Component" = "infra-db"
            "aws:ResourceTag/Project"   = local.project
            "kms:ViaService"            = "rds.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "DatabaseKmsRdsUsage"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:ReEncrypt*",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Component" = "infra-db"
            "aws:ResourceTag/Project"   = local.project
            "kms:ViaService"            = "rds.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "DatabaseManagedSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:TagResource",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:rds!db-*"
      },
      {
        Sid      = "DatabaseKmsSecretsManagerUsage"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey"]
        Resource = "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Component" = "infra-db"
            "aws:ResourceTag/Project"   = local.project
            "kms:ViaService"            = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Sid      = "DatabaseKmsSecretsManagerGrant"
        Effect   = "Allow"
        Action   = ["kms:CreateGrant"]
        Resource = "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
        Condition = {
          Bool = { "kms:GrantIsForAWSResource" = "true" }
          StringEquals = {
            "aws:ResourceTag/Component" = "infra-db"
            "aws:ResourceTag/Project"   = local.project
            "kms:ViaService"            = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "DatabaseKmsAlias"
        Effect = "Allow"
        Action = [
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:UpdateAlias",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alias/soat-oficina-rds"
      },
      {
        Sid    = "DatabaseKmsAliasTarget"
        Effect = "Allow"
        Action = [
          "kms:CreateAlias",
          "kms:UpdateAlias",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Component" = "infra-db"
            "aws:ResourceTag/Project"   = local.project
          }
        }
      },
      {
        Sid    = "RdsMonitoringRoleLifecycle"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:UpdateAssumeRolePolicy",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/soat-oficina-rds-monitoring"
      },
      {
        Sid    = "RdsMonitoringPolicyAttachment"
        Effect = "Allow"
        Action = [
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/soat-oficina-rds-monitoring"
        Condition = {
          StringEquals = {
            "iam:PolicyARN" = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
          }
        }
      },
      {
        Sid      = "PassRdsMonitoringRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/soat-oficina-rds-monitoring"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "monitoring.rds.amazonaws.com"
          }
        }
      },
      {
        Sid      = "AppPodRdsPolicy"
        Effect   = "Allow"
        Action   = ["iam:DeleteRolePolicy", "iam:GetRolePolicy", "iam:PutRolePolicy"]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/soat-oficina-app-pod"
      },
      {
        Sid      = "TerraformStateBucketLocation"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation"]
        Resource = local.state_bucket_arn
      },
      {
        Sid      = "TerraformStateBucketList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = local.state_bucket_arn
        Condition = {
          StringLike = { "s3:prefix" = ["infra-db/*", "infra-k8s/terraform.tfstate"] }
        }
      },
      {
        Sid      = "TerraformStateObjects"
        Effect   = "Allow"
        Action   = local.state_object_actions
        Resource = "${local.state_bucket_arn}/infra-db/*"
      },
      {
        Sid      = "FoundationStateRead"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${local.state_bucket_arn}/infra-k8s/terraform.tfstate"
      },
    ]
  })
}

resource "aws_iam_role_policy" "github_auth" {
  #checkov:skip=CKV_AWS_286: The auth deploy role must create scoped Lambda execution roles; IAM resources use the soat-oficina-auth prefix and PassRole is Lambda-only.
  #checkov:skip=CKV_AWS_289: The approved auth controller must manage only soat-oficina-auth prefixed roles; it cannot manage arbitrary account roles.
  #checkov:skip=CKV_AWS_290: Authentication write actions are enumerated; provisioning APIs without resource-level support require wildcard resources.
  #checkov:skip=CKV_AWS_355: Wildcard resources apply only to enumerated auth actions; IAM and state resources are scoped separately.
  for_each = { for key, role in local.github_deploy_roles : key => role if role.repository == "soat-oficina-auth" }

  name = "phase-3-${each.value.repository}-${each.value.environment}"
  role = aws_iam_role.github_deploy[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AuthenticationServices"
        Effect   = "Allow"
        Action   = local.auth_actions
        Resource = "*"
      },
      {
        Sid    = "AuthenticationIam"
        Effect = "Allow"
        Action = [
          "iam:AttachRolePolicy",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:DeleteRolePolicy",
          "iam:DetachRolePolicy",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:PutRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:UpdateAssumeRolePolicy",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/soat-oficina-auth-*"
      },
      {
        Sid      = "AuthenticationPassRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/soat-oficina-auth-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "lambda.amazonaws.com"
          }
        }
      },
      {
        Sid      = "TerraformStateBucket"
        Effect   = "Allow"
        Action   = local.state_actions
        Resource = local.state_bucket_arn
        Condition = {
          StringLike = { "s3:prefix" = ["auth/*"] }
        }
      },
      {
        Sid      = "TerraformStateObjects"
        Effect   = "Allow"
        Action   = local.state_object_actions
        Resource = "${local.state_bucket_arn}/auth/*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "github_app" {
  #checkov:skip=CKV_AWS_355: GetAuthorizationToken cannot be resource-scoped; all push and cluster actions are scoped in separate statements.
  for_each = { for key, role in local.github_deploy_roles : key => role if role.repository == "soat-oficina-app" }

  name = "phase-3-${each.value.repository}-${each.value.environment}"
  role = aws_iam_role.github_deploy[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuthorization"
        Effect   = "Allow"
        Action   = local.app_actions
        Resource = "*"
      },
      {
        Sid    = "ApplicationRepository"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:ListImages",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid      = "ApplicationCluster"
        Effect   = "Allow"
        Action   = ["eks:AccessKubernetesApi", "eks:DescribeCluster"]
        Resource = module.eks.cluster_arn
      },
    ]
  })
}

resource "aws_eks_access_entry" "app_deploy" {
  for_each = local.environments

  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_deploy["soat-oficina-app:${each.value}"].arn
  type          = "STANDARD"
  tags          = merge(local.common_tags, { Environment = each.value })
}

resource "aws_eks_access_policy_association" "app_deploy" {
  for_each = local.environments

  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.app_deploy[each.value].principal_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [each.value]
  }
}
