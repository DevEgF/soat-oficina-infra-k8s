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
      "repo:example-owner@104474051/soat-oficina-app@1226897491:environment:prod"
    )
    error_message = "prod trust must be scoped to the prod GitHub Environment"
  }

  assert {
    condition = alltrue([
      for action in [
        "cloudwatch:GetDashboard",
        "cloudwatch:ListTagsForResource",
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

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "DatabaseServices" && alltrue([
        for action in [
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "rds:CreateDBSnapshot",
          "rds:CopyDBSnapshot",
          "rds:DeleteDBSnapshot",
          "rds:DescribeDBSnapshots",
          "logs:DescribeLogGroups",
        ] : contains(statement.Action, action)
      ])
    ])
    error_message = "the database deploy role must cover the planned network, snapshot and log discovery lifecycle"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "DatabaseLogGroup" &&
      statement.Resource == "arn:aws:logs:us-east-1:111122223333:log-group:/aws/rds/instance/soat-oficina-db/postgresql:*" &&
      contains(statement.Action, "logs:AssociateKmsKey") && contains(statement.Action, "logs:TagResource")
    ])
    error_message = "database log management must be scoped to the exact PostgreSQL log group"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "DatabaseLogGroupTags" &&
      statement.Resource == "arn:aws:logs:us-east-1:111122223333:log-group:/aws/rds/instance/soat-oficina-db/postgresql" &&
      alltrue([
        for action in ["logs:ListTagsForResource", "logs:TagResource", "logs:UntagResource"] :
        contains(statement.Action, action)
      ])
    ])
    error_message = "database log tagging must use the exact ARN form without the trailing wildcard"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "DatabaseAlarms" &&
      statement.Resource == [
        "arn:aws:cloudwatch:us-east-1:111122223333:alarm:soat-oficina-db-high-connections",
        "arn:aws:cloudwatch:us-east-1:111122223333:alarm:soat-oficina-db-high-cpu",
        "arn:aws:cloudwatch:us-east-1:111122223333:alarm:soat-oficina-db-low-storage",
      ] &&
      alltrue([
        for action in [
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListTagsForResource",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource",
        ] : contains(statement.Action, action)
      ])
    ])
    error_message = "database alarm lifecycle must include tag permissions scoped to the three exact alarm ARNs"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "DatabaseKmsCreate" &&
      contains(statement.Action, "kms:CreateKey") &&
      contains(statement.Action, "kms:TagResource") &&
      statement.Condition.StringEquals["aws:RequestTag/Project"] == "soat-oficina" &&
      statement.Condition.StringEquals["aws:RequestTag/Component"] == "infra-db" &&
      contains(statement.Condition["ForAllValues:StringEquals"]["aws:TagKeys"], "GenerationModel")
    ])
    error_message = "database KMS creation must authorize only the approved initial project tags"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "DatabaseKmsKeyLifecycle" &&
      statement.Resource == "arn:aws:kms:us-east-1:111122223333:key/*" &&
      statement.Condition.StringEquals["aws:ResourceTag/Project"] == "soat-oficina" &&
      statement.Condition.StringEquals["aws:ResourceTag/Component"] == "infra-db"
    ])
    error_message = "database KMS lifecycle actions must be scoped to project-tagged keys"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "RdsMonitoringRoleLifecycle" &&
      statement.Resource == "arn:aws:iam::111122223333:role/soat-oficina-rds-monitoring" &&
      contains(statement.Action, "iam:CreateRole")
    ])
    error_message = "database IAM lifecycle must be scoped to the exact enhanced monitoring role"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "RdsMonitoringPolicyAttachment" &&
      statement.Resource == "arn:aws:iam::111122223333:role/soat-oficina-rds-monitoring" &&
      statement.Condition.StringEquals["iam:PolicyARN"] == "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole" &&
      contains(statement.Action, "iam:AttachRolePolicy")
    ])
    error_message = "monitoring role attachments must be limited to the AWS enhanced monitoring policy"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "DatabaseKmsRdsUsage" &&
      statement.Condition.StringEquals["aws:ResourceTag/Component"] == "infra-db" &&
      statement.Condition.StringEquals["kms:ViaService"] == "rds.us-east-1.amazonaws.com" &&
      contains(statement.Action, "kms:Decrypt") &&
      contains(statement.Action, "kms:ReEncrypt*")
    ])
    error_message = "snapshot copying must use only the infra-db key through RDS"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "DatabaseManagedSecret" &&
      statement.Resource == "arn:aws:secretsmanager:us-east-1:111122223333:secret:rds!db-*" &&
      alltrue([
        for action in ["secretsmanager:CreateSecret", "secretsmanager:DescribeSecret", "secretsmanager:TagResource"] :
        contains(statement.Action, action)
      ])
    ])
    error_message = "RDS managed password creation must be limited to the service-managed secret namespace"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "DatabaseKmsSecretsManagerUsage" &&
      statement.Condition.StringEquals["aws:ResourceTag/Component"] == "infra-db" &&
      statement.Condition.StringEquals["kms:ViaService"] == "secretsmanager.us-east-1.amazonaws.com" &&
      contains(statement.Action, "kms:Decrypt") &&
      contains(statement.Action, "kms:GenerateDataKey")
    ])
    error_message = "the RDS-managed secret must use only the infra-db key through Secrets Manager"
  }

  assert {
    condition = alltrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      !contains(statement.Action, "secretsmanager:GetSecretValue")
    ])
    error_message = "the database deployment role must never read the RDS credential value"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "FoundationStateRead" &&
      statement.Action == ["s3:GetObject"] &&
      statement.Resource == "arn:aws:s3:::soat-oficina-tfstate-111122223333-us-east-1/infra-k8s/terraform.tfstate"
    ])
    error_message = "infra-db must read only the exact foundation remote state object"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "TerraformStateBucketLocation" &&
      statement.Action == ["s3:GetBucketLocation"] &&
      statement.Resource == "arn:aws:s3:::soat-oficina-tfstate-111122223333-us-east-1" &&
      !contains(keys(statement), "Condition")
    ])
    error_message = "GetBucketLocation must not depend on the unsupported s3:prefix condition key"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "TerraformStateBucketList" &&
      statement.Action == ["s3:ListBucket"] &&
      contains(statement.Condition.StringLike["s3:prefix"], "infra-db/*") &&
      contains(statement.Condition.StringLike["s3:prefix"], "infra-k8s/terraform.tfstate")
    ])
    error_message = "ListBucket must be limited to the database state prefix and exact foundation state key"
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "RdsServiceLinkedRole" &&
      statement.Action == ["iam:CreateServiceLinkedRole"] &&
      statement.Resource == "arn:aws:iam::111122223333:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS" &&
      statement.Condition.StringEquals["iam:AWSServiceName"] == "rds.amazonaws.com"
    ])
    error_message = "first RDS deployment must create only the RDS service-linked role"
  }
  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_role_policy.github_infra_db["soat-oficina-infra-db:prod"].policy).Statement :
      statement.Sid == "PassRdsMonitoringRole" &&
      statement.Resource == "arn:aws:iam::111122223333:role/soat-oficina-rds-monitoring" &&
      statement.Condition.StringEquals["iam:PassedToService"] == "rds.amazonaws.com"
    ])
    error_message = "CreateDBInstance passes the monitoring role to RDS, not to the monitoring trust principal"
  }

}
