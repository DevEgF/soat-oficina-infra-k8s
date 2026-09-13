#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
[[ $(id -u) -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
[[ $(uname -m) == aarch64 ]] || { echo 'This bootstrap targets ARM64.' >&2; exit 1; }
version='v1.35.8+k3s1'
if command -v k3s >/dev/null; then
  k3s --version | head -n 1
  echo 'Existing installation preserved; no automatic reinstall.'
  exit 0
fi
[[ ! -e /etc/rancher/k3s/config.yaml ]] || { echo 'Existing K3s configuration requires review.' >&2; exit 1; }
dnf install -y curl ca-certificates container-selinux policycoreutils-python-utils
install -d -m 700 /etc/rancher/k3s
cat > /etc/rancher/k3s/config.yaml <<'YAML'
node-name: oficina-oci
write-kubeconfig-mode: "0600"
secrets-encryption: true
selinux: true
flannel-backend: host-gw
disable:
  - local-storage
kubelet-arg:
  - "image-gc-high-threshold=75"
  - "image-gc-low-threshold=65"
YAML
chmod 600 /etc/rancher/k3s/config.yaml
# Single node: no public Kubernetes API, kubelet, or overlay ports are needed.
if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
  firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  firewall-cmd --reload
fi
installer=$(mktemp)
trap 'rm -f "$installer"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL https://get.k3s.io -o "$installer"
# Official installer verifies the selected release binary against its checksum.
INSTALL_K3S_VERSION="$version" sh "$installer"
k3s kubectl wait --for=condition=Ready node/oficina-oci --timeout=240s
k3s kubectl get nodes -o wide
k3s secrets-encrypt status
