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
  default = "t3.medium"
}
