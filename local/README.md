# Plataforma local (kind + RabbitMQ + docker compose)

Ambiente local da Fase 4: um cluster kind (`oficina`) com RabbitMQ e os Secrets
dos três microsserviços (OS, Billing, Execução), mais um `docker-compose.yml`
com as dependências para desenvolver fora do cluster. Nada aqui toca a AWS nem o
Terraform da Fase 3.

## Pré-requisitos

Docker em execução (recomendado 8 GB), `kind`, `kubectl` e `curl`. Scripts em bash
(compatíveis com o 3.2 do macOS e com Linux).

Arquivo de ambiente: `.env.local` na pasta que contém os repositórios
(`<repo>/../.env.local`), ou outro caminho em `OFICINA_ENV_FILE`. Use
`.env.example` como modelo. `APP_JWT_SECRET` é obrigatório (`openssl rand -hex 32`).

## Comandos

```bash
local/up.sh      # cria o cluster (se não existir), aplica Secrets e RabbitMQ, espera o rollout
local/down.sh    # apaga o cluster
local/secrets.sh # só recria/atualiza os Secrets (idempotente)

docker compose -f local/docker-compose.yml up -d --wait   # dependências fora do cluster
docker compose -f local/docker-compose.yml down -v
```

Todos os comandos `kubectl` usam `--context kind-oficina`; o contexto corrente
da sua máquina não importa.

## Portas (somente 127.0.0.1)

| Porta | Uso |
|---|---|
| 30081 / 30082 / 30083 | NodePort do OS, Billing e Execução (kind) |
| 31672 | Painel do RabbitMQ no cluster (usuário `oficina`) |
| 5672 / 15672 | RabbitMQ no compose (AMQP / painel) |
| 5433 / 5434 | PostgreSQL `os` / `billing` no compose |
| 27017 | MongoDB `execution` no compose |

Dentro do cluster o AMQP é `rabbitmq.oficina.svc:5672`. Usuário/senha do compose:
`oficina`/`oficina` (RabbitMQ), e `os`, `billing`, `execution` com a senha
`oficina`, sobrescrevível pelas variáveis `*_PASSWORD` do `.env.example`.

## Contrato dos Secrets (namespace `oficina`)

| Secret | Chaves |
|---|---|
| `rabbitmq-credentials` | `username`, `password` |
| `os-service-secrets` | `APP_JWT_SECRET`, `SPRING_DATASOURCE_PASSWORD`, `SPRING_RABBITMQ_PASSWORD`, `NEW_RELIC_LICENSE_KEY` |
| `billing-service-secrets` | `APP_JWT_SECRET`, `SPRING_DATASOURCE_PASSWORD`, `SPRING_RABBITMQ_PASSWORD`, `NEW_RELIC_LICENSE_KEY`, `MERCADOPAGO_ACCESS_TOKEN` |
| `execution-service-secrets` | `APP_JWT_SECRET`, `MONGODB_PASSWORD`, `SPRING_RABBITMQ_PASSWORD`, `NEW_RELIC_LICENSE_KEY` |

`NEW_RELIC_LICENSE_KEY` e `MERCADOPAGO_ACCESS_TOKEN` podem ficar vazios (com aviso).
Os valores nunca vão para arquivo versionado nem para a saída do terminal.
Se mudar `RABBITMQ_PASSWORD` com o cluster no ar, reinicie o RabbitMQ:
`kubectl --context kind-oficina -n oficina rollout restart deployment/rabbitmq`.

## Runners do deploy (GitHub Actions self-hosted)

O deploy de cada serviço roda em um runner self-hosted nesta máquina, porque só
ela alcança o cluster kind. A conta `DevEgF` é pessoal, então o registro é por
repositório: `runners.sh` mantém um runner para cada serviço, com o rótulo
`oficina-kind`, em `<pasta dos repositórios>/.runners/`.

```bash
local/runners.sh setup    # baixa o runner (confere o SHA-256) e registra um por repositório
local/runners.sh start    # sobe os processos em segundo plano
local/runners.sh status   # estado local e no GitHub
local/runners.sh stop
local/runners.sh remove   # para e remove o registro no GitHub
```

Requer o GitHub CLI (`gh`) autenticado com administração nos repositórios. Os
runners rodam como o usuário atual, sem serviço do sistema: depois de reiniciar
a máquina, rode `local/runners.sh start` de novo. Os workflows de deploy só
disparam em push na `main`, nunca em pull request.

## Recriar do zero

```bash
local/down.sh && local/up.sh
```

As imagens dos serviços e o conteúdo dos bancos somem junto com o cluster; os
serviços voltam com o `scripts/deploy-kind.sh` de cada repositório.
