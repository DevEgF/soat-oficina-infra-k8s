mock_provider "aws" {
  mock_resource "aws_secretsmanager_secret" {
    override_during = plan
    defaults        = { arn = "arn:aws:secretsmanager:us-east-1:111122223333:secret:fixture" }
  }
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

run "contract_defaults" {
  command = plan

  variables {
    github_owner = "example-owner"
    alert_email  = "owner@example.com"
  }

  assert {
    condition     = output.cluster_name == "soat-oficina-eks"
    error_message = "cluster_name must be stable for remote-state consumers"
  }

  assert {
    condition     = output.environments == toset(["hml", "prod"])
    error_message = "both deployment environments are required"
  }

  assert {
    condition = (
      toset(keys(output.staff_secret_arns)) == toset(["hml", "prod"]) &&
      aws_secretsmanager_secret.staff["hml"].name == "soat-oficina/hml/staff" &&
      aws_secretsmanager_secret.staff["prod"].name == "soat-oficina/prod/staff" &&
      length(local.staff_password_keys) == 10 &&
      alltrue([for statement in jsondecode(aws_iam_role_policy.app_staff_secrets.policy).Statement :
        contains(["hml", "prod"], statement.Condition.StringEquals["aws:PrincipalTag/kubernetes-namespace"]) &&
        statement.Condition.StringEquals["aws:PrincipalTag/kubernetes-service-account"] == "oficina-app" &&
        toset(statement.Action) == toset(["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"])
      ])
    )
    error_message = "Each environment needs its own five staff passwords and namespace-bound runtime access."
  }
}
