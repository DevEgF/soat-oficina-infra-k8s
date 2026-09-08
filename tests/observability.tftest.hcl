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

  mock_resource "aws_lb" {
    override_during = plan

    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:111122223333:loadbalancer/net/soat-oficina-internal/mock"
      arn_suffix = "net/soat-oficina-internal/mock"
    }
  }

  mock_resource "aws_lb_target_group" {
    override_during = plan

    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:111122223333:targetgroup/soat-oficina/mock"
      arn_suffix = "targetgroup/soat-oficina/mock"
    }
  }

}

override_resource {
  target          = aws_cloudwatch_metric_alarm.nlb_unhealthy_hosts["hml"]
  override_during = plan

  values = {
    arn = "arn:aws:cloudwatch:us-east-1:111122223333:alarm:soat-oficina-hml-unhealthy-hosts"
  }
}

override_resource {
  target          = aws_cloudwatch_metric_alarm.nlb_unhealthy_hosts["prod"]
  override_during = plan

  values = {
    arn = "arn:aws:cloudwatch:us-east-1:111122223333:alarm:soat-oficina-prod-unhealthy-hosts"
  }
}

run "dashboard_alarm_widget_schema" {
  command = plan

  variables {
    github_owner = "example-owner"
    alert_email  = "owner@example.com"
  }

  assert {
    condition = try(
      jsondecode(aws_cloudwatch_dashboard.cluster.dashboard_body).widgets[4].type == "alarm" &&
      toset(jsondecode(aws_cloudwatch_dashboard.cluster.dashboard_body).widgets[4].properties.alarms) == toset([
        "arn:aws:cloudwatch:us-east-1:111122223333:alarm:soat-oficina-hml-unhealthy-hosts",
        "arn:aws:cloudwatch:us-east-1:111122223333:alarm:soat-oficina-prod-unhealthy-hosts",
      ]) &&
      jsondecode(aws_cloudwatch_dashboard.cluster.dashboard_body).widgets[4].properties.sortBy == "stateUpdatedTimestamp" &&
      !can(jsondecode(aws_cloudwatch_dashboard.cluster.dashboard_body).widgets[4].properties.metrics) &&
      !can(jsondecode(aws_cloudwatch_dashboard.cluster.dashboard_body).widgets[4].properties.annotations),
      false
    )
    error_message = "environment alarm status must use a valid alarm widget with both environment alarms"
  }
}
