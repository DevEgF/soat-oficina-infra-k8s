variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "github_owner" {
  type = string
}

variable "alert_email" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "node_instance_type" {
  type    = string
  default = "c7i-flex.large"
}

variable "github_owner_id" {
  description = "Immutable GitHub owner ID, confirmed by the repository OIDC subject endpoint."
  type        = string
  default     = "104474051"
  validation {
    condition     = can(regex("^[0-9]+$", var.github_owner_id))
    error_message = "github_owner_id must be a numeric GitHub ID."
  }
}

variable "github_repository_ids" {
  description = "Immutable GitHub repository IDs used in exact OIDC environment subjects."
  type        = map(string)
  default = {
    soat-oficina-infra-k8s = "1354093465"
    soat-oficina-infra-db  = "1354093646"
    soat-oficina-auth      = "1354093823"
    soat-oficina-app       = "1226897491"
  }
  validation {
    condition = alltrue([
      for name in ["soat-oficina-infra-k8s", "soat-oficina-infra-db", "soat-oficina-auth", "soat-oficina-app"] :
      can(regex("^[0-9]+$", var.github_repository_ids[name]))
    ])
    error_message = "All four repositories must have numeric GitHub IDs."
  }
}
