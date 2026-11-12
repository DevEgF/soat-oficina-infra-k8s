#!/usr/bin/env bash
# Cria/atualiza os Secrets do namespace "oficina" a partir do arquivo de ambiente.
# Idempotente (kubectl apply). Nenhum valor vai para saída de terminal nem para
# arquivo versionado: os valores passam por arquivos temporários 0600 removidos
# por trap e entram no kubectl via --from-env-file.
set -euo pipefail

CONTEXT="kind-oficina"
NAMESPACE="oficina"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# <repo>/.. é a pasta que contém os repositórios (e o .env.local).
ENV_FILE="${OFICINA_ENV_FILE:-${SCRIPT_DIR}/../../.env.local}"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERRO: arquivo de ambiente não encontrado: $ENV_FILE" >&2
  echo "      Copie local/.env.example para esse caminho (ou defina OFICINA_ENV_FILE) e preencha." >&2
  exit 1
fi

umask 077
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Lê o valor de uma chave do arquivo (sem "source": o arquivo pode ter outras
# variáveis e não deve ser executado). Aceita "export" e aspas simples/duplas.
# Variável já definida no ambiente do processo tem precedência.
get_value() {
  local key="$1" default="${2-}" line value
  if [ -n "${!key-}" ]; then
    printf '%s' "${!key}"
    return
  fi
  line="$(grep -E "^[[:space:]]*(export[[:space:]]+)?${key}=" "$ENV_FILE" | tail -n 1 || true)"
  if [ -z "$line" ]; then
    printf '%s' "$default"
    return
  fi
  value="${line#*=}"
  value="${value%$'\r'}"
  case "$value" in
    \"*\") value="${value#\"}"; value="${value%\"}" ;;
    \'*\') value="${value#\'}"; value="${value%\'}" ;;
  esac
  printf '%s' "${value:-$default}"
}

JWT_SECRET="$(get_value APP_JWT_SECRET)"
if [ -z "$JWT_SECRET" ]; then
  echo "ERRO: APP_JWT_SECRET é obrigatório (mínimo 32 bytes) e está ausente ou vazio em $ENV_FILE." >&2
  echo "      Gere um com: openssl rand -hex 32" >&2
  exit 1
fi
if [ "${#JWT_SECRET}" -lt 32 ]; then
  echo "ERRO: APP_JWT_SECRET tem ${#JWT_SECRET} caracteres; o mínimo é 32. Gere um com: openssl rand -hex 32" >&2
  exit 1
fi

NEW_RELIC_KEY="$(get_value NEW_RELIC_LICENSE_KEY)"
MP_TOKEN="$(get_value MERCADOPAGO_ACCESS_TOKEN)"
[ -n "$NEW_RELIC_KEY" ] || echo "AVISO: NEW_RELIC_LICENSE_KEY vazio; o agente New Relic ficará desligado." >&2
[ -n "$MP_TOKEN" ] || echo "AVISO: MERCADOPAGO_ACCESS_TOKEN vazio; o Billing Service não conseguirá cobrar de verdade." >&2

RABBITMQ_PASSWORD="$(get_value RABBITMQ_PASSWORD oficina)"
OS_DB_PASSWORD="$(get_value OS_DB_PASSWORD oficina)"
BILLING_DB_PASSWORD="$(get_value BILLING_DB_PASSWORD oficina)"
EXECUTION_DB_PASSWORD="$(get_value EXECUTION_DB_PASSWORD oficina)"

# Senhas dos usuários de staff do OS Service (admin, atendente, tecnico). Sem padrão:
# fora dos perfis local/test o serviço recusa senha vazia ou igual ao nome do usuário.
STAFF_ADMIN_PASSWORD="$(get_value STAFF_ADMIN_PASSWORD)"
STAFF_ATTENDANT_PASSWORD="$(get_value STAFF_ATTENDANT_PASSWORD)"
STAFF_TECHNICIAN_PASSWORD="$(get_value STAFF_TECHNICIAN_PASSWORD)"
for key in STAFF_ADMIN_PASSWORD STAFF_ATTENDANT_PASSWORD STAFF_TECHNICIAN_PASSWORD; do
  if [ -z "${!key}" ]; then
    echo "ERRO: $key é obrigatório e está ausente ou vazio em $ENV_FILE." >&2
    echo "      Gere um com: openssl rand -hex 12" >&2
    exit 1
  fi
done

# Valores com quebra de linha não cabem em --from-env-file.
for v in "$JWT_SECRET" "$NEW_RELIC_KEY" "$MP_TOKEN" "$RABBITMQ_PASSWORD" \
         "$OS_DB_PASSWORD" "$BILLING_DB_PASSWORD" "$EXECUTION_DB_PASSWORD" \
         "$STAFF_ADMIN_PASSWORD" "$STAFF_ATTENDANT_PASSWORD" "$STAFF_TECHNICIAN_PASSWORD"; do
  case "$v" in
    *$'\n'*) echo "ERRO: valores com quebra de linha não são suportados." >&2; exit 1 ;;
  esac
done

KUBECTL=(kubectl --context "$CONTEXT")

# Garante o namespace (o rabbitmq.yaml também o declara; apply é idempotente).
"${KUBECTL[@]}" create namespace "$NAMESPACE" --dry-run=client -o yaml \
  | "${KUBECTL[@]}" apply -f - >/dev/null

# apply_secret <nome> < arquivo-env : cria/atualiza o Secret sem ecoar valores.
apply_secret() {
  local name="$1" envfile="$2"
  "${KUBECTL[@]}" -n "$NAMESPACE" create secret generic "$name" \
    --from-env-file="$envfile" --dry-run=client -o yaml \
    | "${KUBECTL[@]}" apply -f - >/dev/null
  echo "Secret/${name} aplicado"
}

{
  printf 'username=%s\n' "oficina"
  printf 'password=%s\n' "$RABBITMQ_PASSWORD"
} > "$TMP_DIR/rabbitmq"
apply_secret rabbitmq-credentials "$TMP_DIR/rabbitmq"

{
  printf 'APP_JWT_SECRET=%s\n' "$JWT_SECRET"
  printf 'SPRING_DATASOURCE_PASSWORD=%s\n' "$OS_DB_PASSWORD"
  printf 'SPRING_RABBITMQ_PASSWORD=%s\n' "$RABBITMQ_PASSWORD"
  printf 'NEW_RELIC_LICENSE_KEY=%s\n' "$NEW_RELIC_KEY"
  printf 'APP_SECURITY_ADMIN_PASSWORD=%s\n' "$STAFF_ADMIN_PASSWORD"
  printf 'APP_SECURITY_ATTENDANT_PASSWORD=%s\n' "$STAFF_ATTENDANT_PASSWORD"
  printf 'APP_SECURITY_TECHNICIAN_PASSWORD=%s\n' "$STAFF_TECHNICIAN_PASSWORD"
} > "$TMP_DIR/os"
apply_secret os-service-secrets "$TMP_DIR/os"

{
  printf 'APP_JWT_SECRET=%s\n' "$JWT_SECRET"
  printf 'SPRING_DATASOURCE_PASSWORD=%s\n' "$BILLING_DB_PASSWORD"
  printf 'SPRING_RABBITMQ_PASSWORD=%s\n' "$RABBITMQ_PASSWORD"
  printf 'NEW_RELIC_LICENSE_KEY=%s\n' "$NEW_RELIC_KEY"
  printf 'MERCADOPAGO_ACCESS_TOKEN=%s\n' "$MP_TOKEN"
} > "$TMP_DIR/billing"
apply_secret billing-service-secrets "$TMP_DIR/billing"

{
  printf 'APP_JWT_SECRET=%s\n' "$JWT_SECRET"
  printf 'MONGODB_PASSWORD=%s\n' "$EXECUTION_DB_PASSWORD"
  printf 'SPRING_RABBITMQ_PASSWORD=%s\n' "$RABBITMQ_PASSWORD"
  printf 'NEW_RELIC_LICENSE_KEY=%s\n' "$NEW_RELIC_KEY"
} > "$TMP_DIR/execution"
apply_secret execution-service-secrets "$TMP_DIR/execution"
