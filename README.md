# soat-oficina-infra-k8s

> **Ambiente AWS encerrado após a demonstração para evitar custos recorrentes.** A implantação e os testes foram executados; os workflows AWS estão desabilitados e o CI permanece ativo. Consulte o [registro de execução, evidências e limites da remoção](docs/delivery/encerramento-aws.md). Não há endpoint AWS ativo anunciado.

Shared AWS foundation for FIAP SOAT Phase 3: a two-AZ VPC, EKS, immutable ECR,
EKS Pod Identity, one internal NLB, GitHub OIDC roles, observability, and cost
guardrails for the `hml` and `prod` namespaces.

The active AWS Free account plan rejects the originally approved `t3.medium`.
The node group therefore uses the Free-Tier-eligible `c7i-flex.large`, preserving
the same 2 vCPU and 4 GiB capacity while consuming account credits.

## Integration contract

The canonical cross-repository contract is maintained in
[`soat-oficina-app/docs/architecture/integration-contracts.md`](https://github.com/DevEgF/soat-oficina-app/blob/develop/docs/architecture/integration-contracts.md).

## Remote state bootstrap

Run the bootstrap once with the authenticated `oficina-admin` profile in
`us-east-1`. Apply only the saved plan and retain the bucket for the full Phase 3
lifecycle.

```powershell
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan -out=tfplan
terraform -chdir=bootstrap apply tfplan
$env:TF_STATE_BUCKET = terraform -chdir=bootstrap output -raw state_bucket_name
terraform init -backend-config="bucket=$env:TF_STATE_BUCKET" -backend-config="region=us-east-1"
```

The initial order is bootstrap, this foundation, `soat-oficina-infra-db`,
`soat-oficina-auth`, and finally `soat-oficina-app`. The first foundation apply
is local because it creates the OIDC roles later used by GitHub Actions.

## Inputs and outputs

Required inputs are `github_owner`, `alert_email`, and optionally `aws_region`
(default `us-east-1`). GitHub Environments also require `AWS_REGION`,
`AWS_ROLE_ARN`, `TF_STATE_BUCKET`, and `ALERT_EMAIL` variables.

| Output | Consumer |
|---|---|
| `state_bucket_name` (bootstrap) | all Terraform infrastructure repositories |
| `cluster_name` | app |
| `vpc_id` | infra-db, auth |
| `public_subnet_ids` | delivery verification |
| `private_subnet_ids` | infra-db, auth |
| `node_security_group_id` | infra-db |
| `lambda_security_group_id` | infra-db, auth |
| `ecr_repository_url` | app |
| `jwt_secret_arn` | auth, app |
| `staff_secret_arns` | app CSI, exact hml/prod references |
| `app_pod_identity_role_name` | infra-db |
| `hml_listener_arn`, `prod_listener_arn` | auth |
| `hml_target_group_arn`, `prod_target_group_arn` | app and verification |
| `alerts_topic_arn` | infra-db, auth |
| `github_deploy_role_arns` | all four repositories |

`jwt_secret_arn` is sensitive metadata; no secret value is stored in an output.

Staff credentials are generated separately for hml/prod using ephemeral random
passwords and write-only secret versions. Each JSON secret contains `master`,
`admin`, `attendant`, `technician`, `warehouse`. CSI mounts these as
`app.security.<role>.password`; no development default is accepted in deployment.
Pod Identity namespace/service-account session tags restrict each namespace to
its own staff secret. Retain the approved AWS-managed Secrets Manager encryption
for this short-lived environment. Explicit rotation increments the write-only
version and restarts application pods; passwords are never Terraform outputs.
The two extra Secrets Manager secrets are also excluded from the base cost table.

## Plan, apply and destroy

Always review and apply a saved plan:

```powershell
python scripts/aws-cost-estimate.py
terraform plan -var="github_owner=DevEgF" -var="alert_email=owner@example.com" -out=tfplan
terraform show tfplan
terraform apply tfplan
```

Destruction is manual. Use the `destroy` workflow, select `hml` or `prod`, and
type `DESTROY-soat-oficina`. It creates, uploads, and applies a saved destroy
plan. The foundation state is shared, so destroying it affects both namespaces.

```powershell
terraform plan -destroy -var="github_owner=DevEgF" -var="alert_email=owner@example.com" -out=destroy.tfplan
terraform show destroy.tfplan
terraform apply destroy.tfplan
```

The deterministic credit estimate is `US$ 0.25829/hour`, `US$ 10.33` for 40
hours, and `US$ 188.55` for 730 hours. It includes the Secrets Manager interface
endpoint in two AZs. Data processing, storage, logs, NLCUs, secrets, backups,
KMS API requests, and taxes remain variable. The totals above exclude the new
alarm key's base storage charge of [US$ 1/month, prorated hourly](https://aws.amazon.com/kms/pricing/).
Alarm notifications use a
dedicated rotating customer-managed KMS key, since CloudWatch cannot publish
through `alias/aws/sns`; include this key in the pre-apply cost review. Both its
key policy and the SNS topic policy restrict CloudWatch to this account's
`soat-oficina-*` alarms. The monthly AWS Budget is `US$ 20`, with actual-spend
notifications at 50, 75, and 100 percent; it is an alerting guardrail, not a
hard spending cap.

## Verification

```powershell
aws eks describe-cluster --name soat-oficina-eks --region us-east-1
$hmlTargetGroupArn = terraform output -raw hml_target_group_arn
aws elbv2 describe-target-health --target-group-arn $hmlTargetGroupArn
kubectl get nodes
kubectl get pods -A
```

See [architecture](docs/architecture.md) and the [operations runbook](docs/runbook.md)
for boundaries, initial setup, routine deployments, and teardown sequencing.

## GitHub OIDC subject identifiers

The GitHub OIDC subject includes immutable owner and repository IDs. The defaults
in `github_owner_id` and `github_repository_ids` match these four repositories,
verified on 2026-09-08. If recreating the repositories or using another owner,
update both inputs from `gh api repos/OWNER/REPOSITORY/actions/oidc/customization/sub`
and its `sub_claim_prefix`; names alone no longer identify the subject.
Trust remains an exact StringEquals match for the repository and hml/prod environment.
See https://docs.github.com/en/actions/reference/security/oidc#immutable-subject-claims.

The application bootstrap manifest also creates stable `oficina-app` ServiceAccounts in hml and prod before migration hooks run. The application chart does not own those ServiceAccounts or namespaces; uninstalling one application release leaves them available for reinstall and the existing Pod Identity associations.
# Application log transport

The CloudWatch add-on overrides only `application-log.conf`. It tails hml/prod container streams into `/aws/eks/soat-oficina-eks/{environment}/application`, preserving the original message with `log_key log`. This keeps EMF `_aws` at the event root and retains structured request correlation. Host and dataplane log configuration keeps the add-on defaults. Application streams from other namespaces are excluded.

`python scripts/test-log-transport.py` requires Docker, Python and OpenSSL. It runs the pinned official AWS Fluent Bit image against a temporary local HTTPS receiver with synthetic events and credentials. It verifies actual PutLogEvents payloads, split CRI reconstruction, both environment destinations and namespace exclusion without contacting AWS. Terraform tests verify the add-on override; CI runs both checks.

References: [AWS add-on configuration](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/install-CloudWatch-Observability-EKS-addon.html) and [Fluent Bit CloudWatch output](https://docs.fluentbit.io/manual/data-pipeline/outputs/cloudwatch).
