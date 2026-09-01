# soat-oficina-infra-k8s
FIAP SOAT Phase 3 - soat-oficina-infra-k8s

## Integration contract

The canonical cross-repository contract is maintained in
[`soat-oficina-app/docs/architecture/integration-contracts.md`](https://github.com/DevEgF/soat-oficina-app/blob/develop/docs/architecture/integration-contracts.md).

## Remote state bootstrap

Run the bootstrap once with the authenticated `oficina-admin` profile in
`us-east-1`. Apply only the saved plan and retain the bucket for the full Phase 3
lifecycle.

```powershell
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan -out=tfplan
terraform -chdir=bootstrap apply tfplan
$stateBucket = terraform -chdir=bootstrap output -raw state_bucket_name
terraform init -backend-config="bucket=$stateBucket" -backend-config="region=us-east-1"
```
