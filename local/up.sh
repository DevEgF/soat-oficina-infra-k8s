#!/usr/bin/env bash
# Sobe a plataforma local: cluster kind "oficina", namespace, Secrets e RabbitMQ.
# Idempotente: pode ser executado quantas vezes quiser.
set -euo pipefail

CLUSTER="oficina"
CONTEXT="kind-oficina"
NAMESPACE="oficina"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for tool in docker kind kubectl curl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERRO: '$tool' não encontrado no PATH." >&2
    exit 1
  fi
done
if ! docker info >/dev/null 2>&1; then
  echo "ERRO: o daemon do Docker não está respondendo. Inicie o Docker Desktop." >&2
  exit 1
fi

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "Cluster kind '$CLUSTER' já existe."
else
  echo "Criando o cluster kind '$CLUSTER'..."
  kind create cluster --config "$SCRIPT_DIR/kind-config.yaml" --wait 120s
fi

KUBECTL=(kubectl --context "$CONTEXT")

"${KUBECTL[@]}" wait --for=condition=Ready node --all --timeout=120s

echo "Aplicando o namespace e os Secrets..."
"${KUBECTL[@]}" create namespace "$NAMESPACE" --dry-run=client -o yaml \
  | "${KUBECTL[@]}" apply -f - >/dev/null
"$SCRIPT_DIR/secrets.sh"

echo "Aplicando o RabbitMQ..."
"${KUBECTL[@]}" apply -f "$SCRIPT_DIR/rabbitmq.yaml"
"${KUBECTL[@]}" -n "$NAMESPACE" rollout status deployment/rabbitmq --timeout=240s

cat <<MSG

Plataforma local no ar (contexto $CONTEXT, namespace $NAMESPACE).
  Painel do RabbitMQ : http://localhost:31672  (usuário oficina; senha no Secret rabbitmq-credentials)
  AMQP no cluster    : rabbitmq.$NAMESPACE.svc:5672
  OS Service         : http://localhost:30081
  Billing Service    : http://localhost:30082
  Execution Service  : http://localhost:30083
MSG
