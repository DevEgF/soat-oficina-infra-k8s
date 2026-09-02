# Architecture

`soat-oficina-infra-k8s` owns the shared AWS foundation for Phase 3. It creates
one VPC and one EKS cluster for both application environments. Environment
isolation happens in the `hml` and `prod` Kubernetes namespaces and in the
environment-specific NLB listeners, target groups, and GitHub OIDC roles.

## Topology

- VPC `10.20.0.0/16` spans two availability zones in `us-east-1`.
- EKS workers run in public subnets so the approved topology does not require a
  NAT Gateway. RDS and Lambda consumers use private subnets.
- The shared EKS cluster runs one managed `t3.medium` node by default and can
  scale to two nodes.
- One internal NLB routes port `8080` to the hml NodePort `30080` and port
  `8081` to the prod NodePort `30081`.
- ECR stores immutable application images. EKS Pod Identity grants the
  `oficina-app` service account access only to the shared JWT secret ARN.
- CloudWatch log groups retain application logs for seven days. Alarms publish
  to the encrypted SNS alerts topic, and AWS Budgets tracks the approved
  monthly notification thresholds without acting as a hard spending cap.

## State and repository boundaries

The bootstrap configuration creates the versioned and encrypted S3 bucket. The
foundation state uses the fixed key `infra-k8s/terraform.tfstate` with native S3
locking. The bucket is retained separately from the foundation lifecycle.

The database and authentication repositories consume non-secret foundation
metadata from remote state. The application consumes non-secret outputs through
GitHub Environment variables. Secret values never cross repository boundaries;
only ARNs are published, and workloads resolve values at runtime.

## Deployment trust

GitHub Actions authenticates through OIDC. Eight roles scope trust to the exact
repository and GitHub Environment pair for the four repositories and `hml` or
`prod`. The hml role is selected from `develop`; the prod role is selected from
`main`. Both workflows operate on the shared foundation state, while GitHub
Environment protection controls approval and role selection.

CI runs only static validation and mocked Terraform tests. Deploy and destroy
are separate workflows; destroy is manual and requires the exact typed phrase
`DESTROY-soat-oficina`. Both workflows upload and then apply the same saved plan.

The canonical cross-repository interface is documented in
[`soat-oficina-app/docs/architecture/integration-contracts.md`](https://github.com/DevEgF/soat-oficina-app/blob/develop/docs/architecture/integration-contracts.md).
