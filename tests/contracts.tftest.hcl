mock_provider "aws" {}

run "contract_defaults" {
  command = plan

  variables {
    github_owner = "example-owner"
    alert_email  = "owner@example.com"
  }

  assert {
    condition     = output.cluster_name == "soat-oficina-eks"
    error_message = "cluster_name must be stable for remote-state consumers"
  }

  assert {
    condition     = output.environments == toset(["hml", "prod"])
    error_message = "both deployment environments are required"
  }
}
