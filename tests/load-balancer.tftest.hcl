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

run "listener_contract" {
  command = plan

  variables {
    github_owner = "example-owner"
    alert_email  = "owner@example.com"
  }

  assert {
    condition     = aws_lb_listener.environment["hml"].port == 8080
    error_message = "hml listener must be 8080"
  }

  assert {
    condition     = aws_lb_listener.environment["prod"].port == 8081
    error_message = "prod listener must be 8081"
  }

  assert {
    condition     = aws_lb_target_group.environment["hml"].port == 30080
    error_message = "hml NodePort must be 30080"
  }

  assert {
    condition     = aws_lb_target_group.environment["prod"].port == 30081
    error_message = "prod NodePort must be 30081"
  }
}
