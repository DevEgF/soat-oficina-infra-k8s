locals {
  routing = {
    hml = {
      listener  = 8080
      node_port = 30080
    }
    prod = {
      listener  = 8081
      node_port = 30081
    }
  }
}

resource "aws_lb" "internal" {
  #checkov:skip=CKV_AWS_150: Deletion protection must remain disabled for the approved automated teardown.
  #checkov:skip=CKV_AWS_91: NLB access logs require an additional S3 logging boundary outside the cost-aware academic design.
  name               = "${local.project}-internal"
  internal           = true
  load_balancer_type = "network"
  subnets            = module.vpc.private_subnets
  security_groups    = [aws_security_group.nlb.id]

  enable_cross_zone_load_balancing                             = true
  enforce_security_group_inbound_rules_on_private_link_traffic = "off"
}

resource "aws_lb_target_group" "environment" {
  for_each = local.routing

  name        = "${local.project}-${each.key}"
  port        = each.value.node_port
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id

  health_check {
    protocol = "HTTP"
    path     = "/actuator/health"
    port     = "traffic-port"
  }
}

resource "aws_lb_listener" "environment" {
  for_each = local.routing

  load_balancer_arn = aws_lb.internal.arn
  port              = each.value.listener
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.environment[each.key].arn
  }
}

resource "aws_autoscaling_attachment" "environment" {
  #checkov:skip=CKV2_AWS_15: EKS owns the managed node group ASG health-check type; each target group performs the approved HTTP application health check.
  for_each = local.routing

  autoscaling_group_name = module.eks.eks_managed_node_groups["main"].node_group_autoscaling_group_names[0]
  lb_target_group_arn    = aws_lb_target_group.environment[each.key].arn
}
