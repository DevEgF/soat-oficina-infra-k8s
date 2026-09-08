resource "aws_eks_addon" "pod_identity" {
  cluster_name = module.eks.cluster_name
  addon_name   = "eks-pod-identity-agent"
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name = module.eks.cluster_name
  addon_name   = "metrics-server"

  depends_on = [module.eks]
}

resource "aws_eks_addon" "cloudwatch" {
  cluster_name = module.eks.cluster_name
  addon_name   = "amazon-cloudwatch-observability"

  depends_on = [module.eks]
}

resource "aws_eks_addon" "secrets_csi" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-secrets-store-csi-driver-provider"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = module.eks.cluster_name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_name
  addon_name   = "coredns"

  depends_on = [module.eks]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = module.eks.cluster_name
  addon_name   = "kube-proxy"
}
