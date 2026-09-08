module "eks" {
  #checkov:skip=CKV_TF_1: The approved design pins the Terraform Registry module to the exact 21.24.1 release.
  #checkov:skip=CKV_AWS_39: Public API access is required for GitHub-hosted OIDC runners; Kubernetes RBAC and EKS access entries enforce authorization.
  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.1"

  name                                     = local.cluster_name
  kubernetes_version                       = var.kubernetes_version
  endpoint_public_access                   = true
  endpoint_private_access                  = true
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = false
  kms_key_administrators                   = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:user/oficina-admin"]
  access_entries = {
    cluster_creator = {
      principal_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:user/oficina-admin"
      type          = "STANDARD"
      policy_associations = {
        admin = {
          policy_arn   = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
  enable_irsa = false

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  eks_managed_node_groups = {
    main = {
      instance_types           = [var.node_instance_type]
      min_size                 = 1
      desired_size             = 1
      max_size                 = 2
      iam_role_name            = "${local.project}-eks-node"
      iam_role_use_name_prefix = false

      iam_role_additional_policies = {
        CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
        AWSXRayDaemonWriteAccess    = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
      }
    }
  }

  tags = local.common_tags
}
