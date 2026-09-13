# Bootstrap OCI K3s

## Decisão e estado atual

O [README principal](../README.md) reúne as RFCs, a justificativa de custo para encerrar AWS e continuar na Oracle, a escolha do Neon e as evidências de aceite. VM em Ashburn, Oracle Linux 9.8 ARM64, 2 OCPUs e 12 GB; K3s de nó único, não OKE. HTTPS público foi configurado posteriormente no repositório app com Traefik, cert-manager e Let’s Encrypt. As portas 80/443 foram liberadas na security list OCI separadamente destes scripts. Dashboards e alertas New Relic estão nos links do README principal; vídeo concluído conforme o responsável.

Alternative execution target on the existing Oracle Linux 9.8 ARM64 VM. Existing
AWS Terraform/workflows are untouched. Do not run Terraform apply for this task.

Copy bootstrap-k3s.sh, install-helm.sh and namespaces.yaml to the VM, inspect them,
then run with sudo. Bootstrap pins K3s v1.35.8+k3s1; Helm pins v3.20.0 and verifies
the archive SHA256. The bootstrap preserves any existing K3s installation.

K3s uses host-gw networking for this single node, keeps SELinux enforcing,
encrypts Secrets, and writes kubeconfig root-only. Firewalld keeps SSH and opens
HTTP/HTTPS, trusting only the configured pod/service CIDRs for internal routing.
The OCI security list is independent and was not changed by these scripts.
Public API-server, kubelet and overlay ports are not required for this topology.

Observed Ready node, CoreDNS, Traefik, metrics-server and enabled secret encryption
on 2026-09-12. No cluster-level HA is claimed. Back up the K3s datastore and server
token securely before any rebuild; neither belongs in Git or agent output.

Application/Neon/New Relic configuration and actual deployment progress live in
the app repository at deploy/oci/README.md.
