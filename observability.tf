locals {
  alerts_topic_arn  = "arn:${data.aws_partition.current.partition}:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${local.project}-alerts"
  alerts_source_arn = "arn:${data.aws_partition.current.partition}:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${local.project}-*"
}

# CloudWatch cannot publish through the AWS-managed SNS encryption key.
resource "aws_kms_key" "alerts" {
  description             = "Encrypt Oficina alarm notifications"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableAccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowProjectAlarmEncryption"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = ["kms:Decrypt", "kms:GenerateDataKey*"]
        Resource  = "*"
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
          ArnLike      = { "aws:SourceArn" = local.alerts_source_arn }
        }
      }
    ]
  })
  tags = local.common_tags
}

resource "aws_kms_alias" "alerts" {
  name          = "alias/${local.project}-alerts"
  target_key_id = aws_kms_key.alerts.key_id
}

resource "aws_sns_topic" "alerts" {
  name              = "${local.project}-alerts"
  kms_master_key_id = aws_kms_key.alerts.arn
  tags              = local.common_tags
}

resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "sns:*"
        Resource  = local.alerts_topic_arn
      },
      {
        Sid       = "AllowProjectAlarms"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = local.alerts_topic_arn
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
          ArnLike      = { "aws:SourceArn" = local.alerts_source_arn }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_log_group" "application" {
  #checkov:skip=CKV_AWS_158: The approved short-lived environment uses CloudWatch service encryption and seven-day retention.
  #checkov:skip=CKV_AWS_338: The approved cost guardrail explicitly limits application log retention to seven days.
  for_each = local.environments

  name              = "/aws/eks/${local.cluster_name}/${each.key}/application"
  retention_in_days = 7
  tags              = merge(local.common_tags, { Environment = each.value })
}

resource "aws_cloudwatch_metric_alarm" "nlb_unhealthy_hosts" {
  for_each = local.routing

  alarm_name          = "${local.project}-${each.key}-unhealthy-hosts"
  alarm_description   = "Application targets are unhealthy in ${each.key}"
  namespace           = "AWS/NetworkELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.internal.arn_suffix
    TargetGroup  = aws_lb_target_group.environment[each.key].arn_suffix
  }

  tags = merge(local.common_tags, { Environment = each.key })
}

resource "aws_cloudwatch_dashboard" "cluster" {
  dashboard_name = "${local.project}-cluster"
  dashboard_body = jsonencode({
    start          = "-PT8H"
    periodOverride = "inherit"
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# SOAT Oficina cluster health"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 12
        height = 6
        properties = {
          title  = "Node CPU and memory"
          region = var.aws_region
          period = 60
          stat   = "Average"
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", "ClusterName", local.cluster_name],
            [".", "node_memory_utilization", ".", "."],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 1
        width  = 12
        height = 6
        properties = {
          title  = "Running pods"
          region = var.aws_region
          period = 60
          stat   = "Average"
          metrics = [
            ["ContainerInsights", "pod_number_of_running_pods", "ClusterName", local.cluster_name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "NLB healthy hosts"
          region = var.aws_region
          period = 60
          stat   = "Minimum"
          metrics = [
            for environment in sort(keys(local.routing)) :
            ["AWS/NetworkELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.environment[environment].arn_suffix, "LoadBalancer", aws_lb.internal.arn_suffix, { label = environment }]
          ]
        }
      },
      {
        type   = "alarm"
        x      = 12
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "Environment alarm status"
          alarms = [for alarm in aws_cloudwatch_metric_alarm.nlb_unhealthy_hosts : alarm.arn]
          sortBy = "stateUpdatedTimestamp"
        }
      },
    ]
  })
}
