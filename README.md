# soat-oficina-infra-k8s

## Implantação atual e decisões da solução

Atualizado em 12/09/2026 (horário de São Paulo). A solução opera na **Oracle Cloud Infrastructure (OCI), com K3s e PostgreSQL gerenciado no Neon**. A implementação AWS foi executada na etapa anterior e permanece versionada para rastreabilidade. A conta AWS foi encerrada pelo responsável para evitar custos recorrentes; os workflows de deploy AWS permanecem desabilitados. CI de qualidade não é sinônimo de deploy habilitado.

### Por que saímos da AWS e fomos para a Oracle?

A AWS foi escolhida pela familiaridade da equipe e integração entre API Gateway, Lambda, EKS, ECR, RDS, IAM, Secrets Manager e CloudWatch. Essa arquitetura atendia à composição da Fase 3, mas manter control plane, compute, banco e rede gerenciados consumia o orçamento acadêmico mesmo com poucas requisições. Créditos promocionais e alertas de orçamento não eliminam cobranças nem funcionam como bloqueio de gastos.

Após a demonstração AWS, a decisão foi encerrar a conta e aproveitar a VM OCI disponível, com **2 OCPUs, 12 GB de memória e arquitetura ARM64**, para manter a aplicação acessível. O K3s concentra os workloads nessa VM; o Neon mantém o banco fora dela; o New Relic recebe a observabilidade. A mudança foi motivada por continuidade e custo operacional, não por uma falha funcional do PostgreSQL, do EKS ou da AWS. Não há benchmark que demonstre superioridade da Oracle nem promessa de custo zero permanente: franquias, disponibilidade, armazenamento e tráfego dependem das contas e do consumo.

O compromisso aceito é operar um cluster de nó único, administrado pela equipe, e integrar serviços de provedores diferentes. K3s não é OKE/EKS gerenciado; o adaptador HTTP de autenticação não é Lambda/OCI Functions. O código e as evidências AWS continuam relevantes para requisitos específicos de Kubernetes gerenciado e serverless.

### RFCs e evolução das decisões

| Decisão | Histórico | Decisão em operação e consequência |
|---|---|---|
| RFC-0001: nuvem | A proposta inicial considerou GCP; a revisão aceita implementou AWS | Continuação em OCI/K3s após encerramento da conta AWS; mantém containers e contratos, assume operação do nó |
| RFC-0002: banco | PostgreSQL local; proposta Cloud SQL; implementação RDS PostgreSQL 16 | Neon PostgreSQL 16, preservando modelo relacional, JPA e Flyway |
| RFC-0003: autenticação | Proposta anterior com JWKS/OTP; implementação acadêmica CPF + JWT HS256 | Mesmo contrato no adaptador HTTP OCI; OTP e JWKS não são funcionalidades entregues |
| Ambientes | Uma infraestrutura compartilhada para reduzir custo | Namespaces e schemas hml/prod separados, sem isolamento físico nem HA entre nós |
| Segredos OCI | AWS usava Secrets Manager e identidades de workload | Exceção autorizada: arquivos protegidos na VM e Kubernetes Secrets; valores fora do Git e dos logs |
| Entrega OCI | AWS mantém seus workflows e promoção por artefato | Deploy via SSH/Helm, ARM64 por digest; registry e pipeline OCI completos ainda não foram executados |

As RFCs versionadas descrevem a decisão AWS da fase anterior. Esta seção registra a continuação OCI sem reescrever os documentos históricos. Consulte as [RFCs e o contexto completo da aplicação](https://github.com/DevEgF/soat-oficina-app/blob/develop/README.md#rfcs-e-documentação-de-referência).

### Por que PostgreSQL e por que Neon?

O domínio relaciona clientes, veículos, ordens de serviço, serviços, peças e reservas. Transações, chaves estrangeiras, unicidade e consultas relacionais sustentam a consistência de estoque, orçamento e andamento da OS. PostgreSQL preserva as migrations existentes, os tipos temporais, valores monetários em centavos e a integração JPA/Hibernate. Trocar para MySQL exigiria revalidar DDL e semântica temporal; SQL Server acrescentaria mudança de dialeto/licenciamento; uma base documental exigiria remodelar relações sem uma necessidade demonstrada. Essas alternativas não traziam benefício suficiente para justificar a migração de engine.

Neon foi adotado como **serviço PostgreSQL gerenciado externo**, evitando disputar memória, disco e recuperação do banco com os containers na VM pequena. O projeto `oficina` fica em Ohio (`us-east-2`), enquanto a VM OCI fica em Ashburn (`us-ashburn-1`): há dependência de internet e latência entre regiões/provedores. A conexão direta, sem pooler, usa TLS com verificação de certificado; sete migrations Flyway foram aplicadas em cada schema. O banco operacional é `neondb`, com schemas `hml` e `prod`.

Os ambientes compartilham o proprietário do banco: schemas oferecem separação lógica, **não isolamento de privilégios**. Papéis dedicados, restauração ensaiada, capacidade de conexões e política de backup/retenção precisam ser tratados antes de ampliar o uso. Não se afirma aqui que o projeto Neon foi provisionado por Terraform: o módulo IaC de banco preservado é o RDS. Credenciais S3 ou AI Gateway do Neon não substituem credenciais PostgreSQL.

### Repositórios e responsabilidades

| Repositório | Responsabilidade |
|---|---|
| [soat-oficina-app](https://github.com/DevEgF/soat-oficina-app) | Kotlin/Spring, domínio e API, frontend React, Flyway, charts AWS/OCI, smoke e telemetria de negócio |
| [soat-oficina-auth](https://github.com/DevEgF/soat-oficina-auth) | Autenticação de cliente, JWT, handlers Lambda e adaptador HTTP OCI |
| [soat-oficina-infra-k8s](https://github.com/DevEgF/soat-oficina-infra-k8s) | Fundação Terraform AWS e bootstrap da VM/K3s OCI |
| [soat-oficina-infra-db](https://github.com/DevEgF/soat-oficina-infra-db) | Terraform RDS, rede, criptografia e lifecycle do banco AWS preservado |

### Evidências, observabilidade e vídeo

- [Saúde HML](https://hml.129.213.121.122.sslip.io/actuator/health) e [saúde PROD](https://oficina.129.213.121.122.sslip.io/actuator/health): HTTPS validado com certificado Let's Encrypt; endereço gratuito baseado no IP via sslip.io.
- [Dashboard HML](https://one.newrelic.com/dashboards/detail/ODQzOTI5M3xWSVp8REFTSEJPQVJEfGRhOjEzMTY1MzA5?account=8439293) e [dashboard PROD](https://one.newrelic.com/dashboards/detail/ODQzOTI5M3xWSVp8REFTSEJPQVJEfGRhOjEzMTY1MzEw?account=8439293): negócio, API/auth e Kubernetes. São privados e exigem acesso à conta New Relic.
- [Alertas New Relic](https://one.newrelic.com/alerts?account=8439293&duration=259200000): o ensaio HML enviou 80 chamadas controladas, 40 respostas 400 e 40 respostas 401, e confirmou dois incidentes críticos. São rejeições de autenticação, não erros internos 5xx; consultar também incidentes fechados e o período de 12/09/2026, 23h15 BRT, se não estiverem ativos.
- Jornada HML verificada até OS entregue, autorização por proprietário, bloqueio de acesso administrativo por cliente e rejeição de JWT entre ambientes. Produção foi validada com saúde, login e leitura, sem criar OS de teste.
- Rollback OCI verificado com mudança de configuração Helm, preservando a OS e os mesmos digests. Não equivale a rollback de binário ou reversão de migrations.
- **Vídeo: gravado com todos os requisitos, conforme confirmação do responsável.** Não é pendência de gravação. O endereço do vídeo não foi informado nesta atualização; não se inventa link nem se declara revisão independente da gravação.

As evidências descrevem o ensaio realizado, não uma garantia de disponibilidade contínua. Não foi comprovada entrega de notificações por e-mail/Slack. A instalação OCI não inclui publicação do frontend, registry remoto ou pipeline completa de promoção OCI. Essas diferenças técnicas permanecem explícitas mesmo com o vídeo concluído.

## Arquitetura AWS preservada e verificações locais

Shared AWS foundation for FIAP SOAT Phase 3: a two-AZ VPC, EKS, immutable ECR,
EKS Pod Identity, one internal NLB, GitHub OIDC roles, observability, and cost
guardrails for the `hml` and `prod` namespaces.

During the AWS deployment, the Free account plan rejected the originally approved `t3.medium`.
The preserved node group configuration therefore uses the Free-Tier-eligible `c7i-flex.large`, preserving
the same 2 vCPU and 4 GiB capacity while consuming account credits.

## Integration contract

The canonical cross-repository contract is maintained in
[`soat-oficina-app/docs/architecture/integration-contracts.md`](https://github.com/DevEgF/soat-oficina-app/blob/develop/docs/architecture/integration-contracts.md).

For the active OCI target, see [bootstrap and operations](oci/README.md). All AWS apply/destroy commands below are historical operating procedures, not commands to run against the closed account. Cost estimates below belong to the recorded AWS plan and are not current price quotations.

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
