# Bootstrap OCI K3s

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
