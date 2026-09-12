data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  #checkov:skip=CKV_TF_1: The approved design pins the Terraform Registry module to the exact 6.6.1 release.
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name                    = "${local.project}-vpc"
  cidr                    = "10.20.0.0/16"
  azs                     = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets          = ["10.20.0.0/24", "10.20.1.0/24"]
  private_subnets         = ["10.20.10.0/24", "10.20.11.0/24"]
  enable_nat_gateway      = false
  map_public_ip_on_launch = true
  public_subnet_tags      = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags     = { "kubernetes.io/role/internal-elb" = "1" }
  tags                    = local.common_tags
}

resource "aws_security_group" "lambda" {
  #checkov:skip=CKV2_AWS_5: This shared security group is exported for Lambda ENIs created by the auth repository.
  name        = "${local.project}-lambda"
  description = "Outbound access for private Lambda functions"
  vpc_id      = module.vpc.vpc_id

  #checkov:skip=CKV_AWS_382: Private Lambda subnets have no NAT or internet route; destination security groups still restrict RDS and endpoint access.
  egress {
    description = "Allow private Lambda functions to reach approved VPC destinations"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "secrets_endpoint" {
  name        = "${local.project}-secrets-endpoint"
  description = "HTTPS access to the private Secrets Manager endpoint"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group" "nlb" {
  name        = "${local.project}-nlb"
  description = "Restricted traffic for the shared internal NLB"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "nlb_to_nodes" {
  for_each = local.routing

  security_group_id            = aws_security_group.nlb.id
  referenced_security_group_id = module.eks.node_security_group_id
  description                  = "Forward ${each.key} traffic to its NodePort"
  from_port                    = each.value.node_port
  to_port                      = each.value.node_port
  ip_protocol                  = "tcp"
}

# HTTP API VPC links use ENIs carrying this security group. The NLB's
# PrivateLink bypass applies to legacy REST API links, not these connections.
resource "aws_vpc_security_group_ingress_rule" "nlb_from_vpc_link" {
  for_each = local.routing

  security_group_id            = aws_security_group.nlb.id
  referenced_security_group_id = aws_security_group.lambda.id
  description                  = "Accept ${each.key} listener traffic from the HTTP API VPC link"
  from_port                    = each.value.listener
  to_port                      = each.value.listener
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nodes_from_nlb" {
  for_each = local.routing

  security_group_id            = module.eks.node_security_group_id
  referenced_security_group_id = aws_security_group.nlb.id
  description                  = "Accept ${each.key} traffic only from the internal NLB"
  from_port                    = each.value.node_port
  to_port                      = each.value.node_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "secrets_from_lambda" {
  security_group_id            = aws_security_group.secrets_endpoint.id
  referenced_security_group_id = aws_security_group.lambda.id
  description                  = "Allow HTTPS from private Lambda functions"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "secrets_from_nodes" {
  security_group_id            = aws_security_group.secrets_endpoint.id
  referenced_security_group_id = module.eks.node_security_group_id
  description                  = "Allow HTTPS from EKS nodes"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.secrets_endpoint.id]
}
