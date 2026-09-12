# Registro de execução e encerramento AWS - Fundação Kubernetes e rede

## Por que o serviço AWS foi encerrado

O ambiente foi criado temporariamente para integração, validação e gravação da Fase 3. Após concluir a demonstração e preservar o vídeo e as evidências, o responsável encerrou a conta AWS para evitar custos recorrentes de manter a infraestrutura ligada.

A limpeza começou somente depois da verificação do vídeo. Durante esse processo, o acesso à AWS foi bloqueado e a tela de login informou suspensão; posteriormente, o responsável confirmou que encerrou a conta. O encerramento foi informado pelo titular. Não foi possível consultar independentemente o inventário final, e este documento não afirma que todos os recursos foram individualmente destruídos ou que o saldo final foi auditado.

## Estado atual de CI/CD e acesso

- Os workflows que acessam a AWS foram desabilitados manualmente no GitHub nos quatro repositórios; os arquivos permanecem versionados como documentação executável da entrega.
- Os workflows de CI permanecem ativos para testes e validações sem deploy AWS. Nenhum workflow de nuvem deve ser reativado automaticamente por esta documentação.
- Os links de Actions abaixo são evidências históricas de execução, não endpoints ativos. O ambiente AWS foi encerrado após a demonstração e não é oferecido para acesso atual do avaliador.
- Os quatro repositórios são públicos. O acesso de escrita do usuário `soat-architecture` foi reconfirmado nos quatro, sem convite pendente.
- Código, documentação e histórico de PRs foram preservados. Não é necessário reabrir a conta apenas para ler os repositórios ou assistir ao vídeo preservado.

Uma futura implantação dependerá de decisão explícita do responsável, conta acessível, revisão de custos/permissões e novos planos Terraform. Não reaplicar planos históricos nem presumir recursos ainda existentes.

## O que foi executado

- Terraform provisionou VPC, EKS, ECR, NLB interno, IAM/OIDC, Pod Identity e recursos de observabilidade utilizados pela entrega.
- O ambiente acadêmico operou com um nó c7i-flex.large e namespaces hml/prod. Probes, HPA por CPU/memória e migrações em Job foram usados pela aplicação.
- A fundação foi integrada aos quatro repositórios; após o bootstrap inicial, os workflows autenticaram na AWS por OIDC.
- Foram corrigidas a publicação de alarmes via SNS com KMS e a regra restrita de acesso do VPC Link ao NLB. Os deploys e testes de APIs em ambos os ambientes passaram.
- Logs estruturados preservaram o requestId entre Gateway e aplicação; métricas e traces reais foram coletados antes do encerramento.

### Evidências públicas

- [Deploy final da fundação em main](https://github.com/DevEgF/soat-oficina-infra-k8s/actions/runs/34663970068).
- [Aplicação hml](https://github.com/DevEgF/soat-oficina-app/actions/runs/34664972364) e [produção](https://github.com/DevEgF/soat-oficina-app/actions/runs/34665628443).

### Limite da remoção

As aplicações foram removidas por seus workflows, mas a destruição integral da fundação não foi executada antes de o acesso à conta ficar indisponível. As consultas posteriores de EKS/RDS falharam na autenticação. Portanto, não há comprovação de exclusão individual de cluster, rede, ECR, bucket de estado ou demais recursos remanescentes.

O motivo do encerramento da conta foi evitar custos recorrentes após a demonstração. O código permanece reproduzível, mas o ambiente não é anunciado como disponível. A topologia de um nó e banco Single-AZ é uma escolha acadêmica de custo, não uma garantia de alta disponibilidade corporativa.

## Registros dos quatro componentes

- [Aplicação](https://github.com/DevEgF/soat-oficina-app/blob/main/docs/delivery/encerramento-aws.md)
- [Autenticação](https://github.com/DevEgF/soat-oficina-auth/blob/main/docs/delivery/encerramento-aws.md)
- [Fundação EKS](https://github.com/DevEgF/soat-oficina-infra-k8s/blob/main/docs/delivery/encerramento-aws.md)
- [Banco RDS](https://github.com/DevEgF/soat-oficina-infra-db/blob/main/docs/delivery/encerramento-aws.md)

As datas dos workflows podem aparecer em 12/09/2026 UTC; a demonstração foi gravada em 11/09/2026 no horário de Brasília.
