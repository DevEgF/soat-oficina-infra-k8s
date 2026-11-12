#!/usr/bin/env bash
# Apaga o cluster kind "oficina" (e tudo que existe nele).
set -euo pipefail

CLUSTER="oficina"

if ! command -v kind >/dev/null 2>&1; then
  echo "ERRO: 'kind' não encontrado no PATH." >&2
  exit 1
fi

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind delete cluster --name "$CLUSTER"
else
  echo "Cluster kind '$CLUSTER' não existe; nada a fazer."
fi
