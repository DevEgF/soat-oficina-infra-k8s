mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }
}

run "network_contract" {
  command = plan

  variables {
    github_owner = "example-owner"
    alert_email  = "owner@example.com"
  }

  assert {
    condition     = module.vpc.vpc_cidr_block == "10.20.0.0/16"
    error_message = "unexpected VPC CIDR"
  }

  assert {
    condition     = module.vpc.natgw_ids == []
    error_message = "NAT Gateway is outside the approved design"
  }

  assert {
    condition     = length(module.vpc.private_subnets) == 2
    error_message = "two private subnets required"
  }
}
