mock_provider "aws" {
  mock_resource "aws_kms_key" {
    override_during = plan
    defaults = {
      arn = "arn:aws:kms:us-east-1:111122223333:key/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    }
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

  assert {
    condition = (
      keys(jsondecode(aws_eks_addon.cloudwatch.configuration_values).containerLogs.fluentBit.config.extraFiles) == ["application-log.conf"] &&
      alltrue([for environment in ["hml", "prod"] : strcontains(
        jsondecode(aws_eks_addon.cloudwatch.configuration_values).containerLogs.fluentBit.config.extraFiles["application-log.conf"],
        "/aws/eks/${local.cluster_name}/${environment}/application"
      )]) &&
      length(regexall("log_key[ ]+log", jsondecode(aws_eks_addon.cloudwatch.configuration_values).containerLogs.fluentBit.config.extraFiles["application-log.conf"])) == 2
    )
    error_message = "Application logs must preserve the original EMF payload in each environment's group while retaining host/dataplane defaults."
  }

  variables {
    github_owner = "example-owner"
    alert_email  = "owner@example.com"
  }

  assert {
    condition = try(
      toset(jsondecode(aws_sns_topic_policy.alerts.policy).Statement[0].Action) == toset([
        "sns:GetTopicAttributes", "sns:SetTopicAttributes", "sns:AddPermission", "sns:RemovePermission",
        "sns:DeleteTopic", "sns:Subscribe", "sns:ListSubscriptionsByTopic", "sns:Publish",
      ]) &&
      jsondecode(aws_sns_topic_policy.alerts.policy).Statement[0].Principal.AWS == "arn:aws:iam::111122223333:root" &&
      jsondecode(aws_sns_topic_policy.alerts.policy).Statement[0].Resource == "arn:aws:sns:us-east-1:111122223333:soat-oficina-alerts",
      false
    )
    error_message = "SNS topic administration must enumerate supported topic-policy actions, scoped to this account and topic; sns:* is rejected by SetTopicAttributes."
  }

  assert {
    condition = (
      aws_sns_topic.alerts.kms_master_key_id == aws_kms_key.alerts.arn &&
      aws_kms_key.alerts.enable_key_rotation &&
      jsondecode(aws_kms_key.alerts.policy).Statement[1].Principal.Service == "cloudwatch.amazonaws.com" &&
      toset(jsondecode(aws_kms_key.alerts.policy).Statement[1].Action) == toset(["kms:Decrypt", "kms:GenerateDataKey*"]) &&
      jsondecode(aws_kms_key.alerts.policy).Statement[1].Condition.StringEquals["aws:SourceAccount"] == "111122223333" &&
      jsondecode(aws_kms_key.alerts.policy).Statement[1].Condition.ArnLike["aws:SourceArn"] == "arn:aws:cloudwatch:us-east-1:111122223333:alarm:soat-oficina-*"
    )
    error_message = "Alarm encryption must allow only this account's Oficina CloudWatch alarms through a rotating customer-managed key."
  }

  assert {
    condition = (
      jsondecode(aws_sns_topic_policy.alerts.policy).Statement[1].Principal.Service == "cloudwatch.amazonaws.com" &&
      jsondecode(aws_sns_topic_policy.alerts.policy).Statement[1].Action == "sns:Publish" &&
      jsondecode(aws_sns_topic_policy.alerts.policy).Statement[1].Resource == "arn:aws:sns:us-east-1:111122223333:soat-oficina-alerts" &&
      jsondecode(aws_sns_topic_policy.alerts.policy).Statement[1].Condition.StringEquals["aws:SourceAccount"] == "111122223333" &&
      jsondecode(aws_sns_topic_policy.alerts.policy).Statement[1].Condition.ArnLike["aws:SourceArn"] == "arn:aws:cloudwatch:us-east-1:111122223333:alarm:soat-oficina-*"
    )
    error_message = "SNS publishing must be scoped to Oficina alarms in the same region and account."
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
