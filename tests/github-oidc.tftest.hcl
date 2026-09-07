mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition          = "aws"
      dns_suffix         = "amazonaws.com"
      reverse_dns_prefix = "com.amazonaws"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
      arn        = "arn:aws:iam::111122223333:user/terraform-test"
      user_id    = "AIDATESTUSER"
    }
  }

  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn = "arn:aws:iam::111122223333:user/terraform-test"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json          = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
      minified_json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "oidc_scope" {
  command = plan

  variables {
    github_owner = "example-owner"
    alert_email  = "owner@example.com"
  }

  assert {
    condition = strcontains(
      aws_iam_role.github_deploy["soat-oficina-app:prod"].assume_role_policy,
      "repo:example-owner/soat-oficina-app:environment:prod"
    )
    error_message = "prod trust must be scoped to the prod GitHub Environment"
  }

  assert {
    condition = alltrue([
      for action in [
        "ec2:CreateNetworkAclEntry",
        "ec2:CreateLaunchTemplate",
        "ec2:CreateLaunchTemplateVersion",
        "ec2:DeleteNetworkAclEntry",
        "ec2:DeleteLaunchTemplate",
        "ec2:DeleteLaunchTemplateVersions",
        "ec2:DescribeLaunchTemplates",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:DescribeNetworkAcls",
        "ec2:DescribePrefixLists",
        "ec2:DescribeVpcAttribute",
        "ec2:ModifyLaunchTemplate",
        "elasticloadbalancing:DescribeCapacityReservation",
        "elasticloadbalancing:DescribeListenerAttributes",
        "elasticloadbalancing:SetSecurityGroups",
        "kms:EnableKeyRotation",
        "secretsmanager:GetResourcePolicy",
        "sns:GetSubscriptionAttributes",
        ] : contains(flatten([
          for statement in jsondecode(aws_iam_role_policy.github_infra_k8s["soat-oficina-infra-k8s:prod"].policy).Statement :
          statement.Action if statement.Sid == "FoundationServices"
      ]), action)
    ])
    error_message = "the foundation deploy role must include the observed Terraform lifecycle actions"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_k8s["soat-oficina-infra-k8s:prod"].policy).Statement :
      statement.Sid == "FoundationBudget" &&
      alltrue([
        for action in [
          "budgets:ListTagsForResource",
          "budgets:ModifyBudget",
          "budgets:TagResource",
          "budgets:UntagResource",
          "budgets:ViewBudget",
        ] : contains(statement.Action, action)
      ]) &&
      statement.Resource == "arn:aws:budgets::111122223333:budget/soat-oficina-*"
    ])
    error_message = "budget management must use valid IAM actions scoped to project budgets"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_k8s["soat-oficina-infra-k8s:prod"].policy).Statement :
      statement.Sid == "FoundationBillingAccess" &&
      alltrue([
        for action in ["aws-portal:ModifyBilling", "aws-portal:ViewBilling"] :
        contains(statement.Action, action)
      ]) &&
      statement.Resource == "*"
    ])
    error_message = "budget API calls require the documented Billing portal permissions"
  }

  assert {
    condition = alltrue([
      for action in [
        "budgets:CreateBudget",
        "budgets:CreateNotification",
        "budgets:DeleteBudget",
        "budgets:DescribeBudget",
        "budgets:DescribeNotificationsForBudget",
        "budgets:DescribeSubscribersForNotification",
        ] : !contains(flatten([
          for statement in jsondecode(aws_iam_role_policy.github_infra_k8s["soat-oficina-infra-k8s:prod"].policy).Statement :
          statement.Action
      ]), action)
    ])
    error_message = "Budgets API operation names must not be used as IAM actions"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_k8s["soat-oficina-infra-k8s:prod"].policy).Statement :
      statement.Sid == "FoundationEksAmiParameter" &&
      contains(statement.Action, "ssm:GetParameter") &&
      statement.Resource == "arn:aws:ssm:us-east-1::parameter/aws/service/eks/optimized-ami/*"
    ])
    error_message = "EKS AMI lookup must be limited to the public optimized-ami parameter path"
  }
}
