locals {
  project      = "soat-oficina"
  cluster_name = "${local.project}-eks"
  environments = toset(["hml", "prod"])
  common_tags = {
    Project   = local.project
    ManagedBy = "terraform"
    Phase     = "3"
  }
}
