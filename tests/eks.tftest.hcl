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

run "eks_contract" {
  command = plan

  variables {
    github_owner = "example-owner"
    alert_email  = "owner@example.com"
  }

  assert {
    condition     = output.kubernetes_version == "1.35"
    error_message = "EKS must remain on standard support"
  }

  assert {
    condition     = output.node_instance_type == "c7i-flex.large"
    error_message = "node must preserve 2 vCPU and 4 GiB on the free account plan"
  }

  assert {
    condition     = aws_eks_addon.metrics_server.addon_name == "metrics-server"
    error_message = "HPA needs Metrics Server"
  }
}
