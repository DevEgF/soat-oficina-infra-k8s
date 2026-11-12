#!/usr/bin/env bash
# Runners self-hosted do GitHub Actions para o deploy no kind local.
#
# A conta DevEgF é pessoal, então o runner é registrado por repositório: um
# diretório e um processo para cada serviço. Os runners rodam como o usuário
# atual (sem serviço do sistema) e param quando a máquina reinicia.
#
# Uso:
#   local/runners.sh setup    # baixa o runner, registra um por repositório
#   local/runners.sh start    # sobe os processos em segundo plano
#   local/runners.sh status   # estado local e no GitHub
#   local/runners.sh stop     # para os processos
#   local/runners.sh remove   # para e remove o registro no GitHub
#
# Requer o GitHub CLI (gh) autenticado com permissão de administração nos
# repositórios, além de docker, kind e kubectl no PATH (o deploy usa os três).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

OWNER="${GITHUB_OWNER:-DevEgF}"
REPOS="${OFICINA_RUNNER_REPOS:-soat-oficina-os-service soat-oficina-billing-service soat-oficina-execution-service}"
RUNNER_VERSION="${RUNNER_VERSION:-2.338.2}"
RUNNERS_HOME="${OFICINA_RUNNERS_HOME:-$WORKSPACE_DIR/.runners}"
RUNNER_LABEL="oficina-kind"

log() { printf '%s\n' "$*"; }
die() { printf 'erro: %s\n' "$*" >&2; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' não encontrado no PATH"
}

platform() {
  local os arch
  case "$(uname -s)" in
    Darwin) os="osx" ;;
    Linux) os="linux" ;;
    *) die "sistema não suportado: $(uname -s)" ;;
  esac
  case "$(uname -m)" in
    arm64 | aarch64) arch="arm64" ;;
    x86_64 | amd64) arch="x64" ;;
    *) die "arquitetura não suportada: $(uname -m)" ;;
  esac
  printf '%s-%s' "$os" "$arch"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# Baixa o pacote do runner uma vez e confere o SHA-256 publicado na release.
download_runner() {
  local plat file url expected actual
  plat="$(platform)"
  file="actions-runner-${plat}-${RUNNER_VERSION}.tar.gz"
  mkdir -p "$RUNNERS_HOME/cache"
  if [ ! -f "$RUNNERS_HOME/cache/$file" ]; then
    url="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${file}"
    log "baixando $file"
    curl -fsSL "$url" -o "$RUNNERS_HOME/cache/$file.part"
    mv "$RUNNERS_HOME/cache/$file.part" "$RUNNERS_HOME/cache/$file"
  fi
  expected="$(gh api "repos/actions/runner/releases/tags/v${RUNNER_VERSION}" --jq .body |
    sed -n "s/.*BEGIN SHA ${plat} -->\([0-9a-f]\{64\}\)<!-- END SHA ${plat}.*/\1/p" | head -n 1)"
  [ -n "$expected" ] || die "não encontrei o SHA-256 de ${plat} na release v${RUNNER_VERSION}"
  actual="$(sha256_of "$RUNNERS_HOME/cache/$file")"
  if [ "$expected" != "$actual" ]; then
    rm -f "$RUNNERS_HOME/cache/$file"
    die "SHA-256 do runner não confere; o arquivo foi removido"
  fi
  printf '%s' "$RUNNERS_HOME/cache/$file"
}

runner_dir() { printf '%s/%s' "$RUNNERS_HOME" "$1"; }

runner_pid() {
  # O Runner.Listener é o processo que mantém a sessão com o GitHub.
  pgrep -f "$(runner_dir "$1")/bin/Runner.Listener" | head -n 1 || true
}

setup_one() {
  local repo="$1" dir tarball token
  dir="$(runner_dir "$repo")"
  if [ -f "$dir/.runner" ]; then
    log "$repo: já registrado"
    return 0
  fi
  gh api "repos/$OWNER/$repo" --jq .full_name >/dev/null 2>&1 ||
    die "repositório $OWNER/$repo não encontrado (ou sem acesso)"
  tarball="$(download_runner)"
  mkdir -p "$dir"
  tar -xzf "$tarball" -C "$dir"
  token="$(gh api -X POST "repos/$OWNER/$repo/actions/runners/registration-token" --jq .token)"
  (
    cd "$dir"
    ./config.sh --unattended \
      --url "https://github.com/$OWNER/$repo" \
      --token "$token" \
      --name "$(hostname -s)-$repo" \
      --labels "$RUNNER_LABEL" \
      --work _work \
      --replace >/dev/null
  )
  log "$repo: registrado com o rótulo $RUNNER_LABEL"
}

start_one() {
  local repo="$1" dir pid
  dir="$(runner_dir "$repo")"
  [ -f "$dir/.runner" ] || die "$repo: runner não registrado; rode 'setup' antes"
  pid="$(runner_pid "$repo")"
  if [ -n "$pid" ]; then
    log "$repo: já está rodando (pid $pid)"
    return 0
  fi
  (
    cd "$dir"
    nohup ./run.sh >>"$dir/runner.log" 2>&1 </dev/null &
  )
  log "$repo: iniciado (log em $dir/runner.log)"
}

stop_one() {
  local repo="$1" dir
  dir="$(runner_dir "$repo")"
  if [ -z "$(runner_pid "$repo")" ]; then
    log "$repo: não está rodando"
    return 0
  fi
  pkill -f "$dir/run.sh" 2>/dev/null || true
  pkill -f "$dir/run-helper.sh" 2>/dev/null || true
  pkill -f "$dir/bin/Runner.Listener" 2>/dev/null || true
  log "$repo: parado"
}

status_one() {
  local repo="$1" pid remote
  pid="$(runner_pid "$repo")"
  remote="$(gh api "repos/$OWNER/$repo/actions/runners" \
    --jq '[.runners[] | "\(.name)=\(.status)\(if .busy then " (ocupado)" else "" end)"] | join(", ")' 2>/dev/null || true)"
  if [ -n "$pid" ]; then
    pid="pid $pid"
  else
    pid="parado"
  fi
  log "$repo: local=$pid github=${remote:-nenhum runner}"
}

remove_one() {
  local repo="$1" dir token
  dir="$(runner_dir "$repo")"
  stop_one "$repo"
  if [ -f "$dir/.runner" ]; then
    token="$(gh api -X POST "repos/$OWNER/$repo/actions/runners/remove-token" --jq .token)"
    (cd "$dir" && ./config.sh remove --token "$token" >/dev/null)
    log "$repo: registro removido"
  fi
}

main() {
  local cmd="${1:-}" repo
  case "$cmd" in
    setup | start | stop | status | remove) ;;
    *) die "uso: $0 setup|start|stop|status|remove" ;;
  esac
  need gh
  if [ "$cmd" = "setup" ] || [ "$cmd" = "start" ]; then
    need docker
    need kind
    need kubectl
  fi
  for repo in $REPOS; do
    "${cmd}_one" "$repo"
  done
}

main "$@"
