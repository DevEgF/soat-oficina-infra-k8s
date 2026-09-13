#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
[[ $(id -u) -eq 0 && $(uname -m) == aarch64 ]] || exit 1
if command -v helm >/dev/null; then helm version --short; exit 0; fi
directory=$(mktemp -d)
trap 'rm -rf "$directory"' EXIT
curl -fsSL https://get.helm.sh/helm-v3.20.0-linux-arm64.tar.gz -o "$directory/helm.tar.gz"
printf '%s  %s\n' bfb14953295d5324d47ab55f3dfba6da28d46c848978c8fbf412d4271bdc29f1 "$directory/helm.tar.gz" | sha256sum -c -
tar -xzf "$directory/helm.tar.gz" -C "$directory" linux-arm64/helm
install -m 755 "$directory/linux-arm64/helm" /usr/local/bin/helm
helm version --short
