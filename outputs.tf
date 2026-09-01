output "cluster_name" {
  value = local.cluster_name
}

output "environments" {
  value = local.environments
}

output "kubernetes_version" {
  value = var.kubernetes_version
}

output "node_instance_type" {
  value = var.node_instance_type
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "lambda_security_group_id" {
  value = aws_security_group.lambda.id
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "node_autoscaling_group_names" {
  value = module.eks.eks_managed_node_groups_autoscaling_group_names
}
