# Operations runbook

## Prerequisites

- Terraform `>= 1.11, < 2.0`, AWS CLI, TFLint, Checkov, `kubectl`, and an
  authenticated AWS identity authorized for the planned changes.
- Region `us-east-1`.
- The GitHub owner and the notification email supplied as Terraform variables.

Never retrieve a secret value for deployment or verification. Only secret ARNs
are Terraform outputs.

## Free account plan compatibility

The AWS account uses the active Free account plan. AWS rejected the approved
`t3.medium` node because it is not Free Tier eligible, so the implementation
uses `c7i-flex.large`, which preserves 2 vCPU and 4 GiB. Usage consumes account
credits and must be destroyed after the delivery window.

Confirm the plan and remaining credits before every apply:

```powershell
aws freetier get-account-plan-state --region us-east-1 --profile oficina-admin
python scripts/aws-cost-estimate.py
```

## Initial bootstrap and foundation apply

Run the bootstrap once and apply only its saved plan:

```powershell
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan -out=tfplan
terraform -chdir=bootstrap apply tfplan
$env:TF_STATE_BUCKET = terraform -chdir=bootstrap output -raw state_bucket_name
```

Initialize the fixed state key, inspect the plan and cost estimate, then apply
only after the explicit apply gate is approved:

```powershell
terraform init -backend-config="bucket=$env:TF_STATE_BUCKET" -backend-config="region=us-east-1"
python scripts/aws-cost-estimate.py
terraform plan -var="github_owner=DevEgF" -var="alert_email=owner@example.com" -out=tfplan
terraform show tfplan
terraform apply tfplan
```

After the initial apply, populate each repository's `hml` and `prod` GitHub
Environment variables from the non-secret outputs: `AWS_REGION`,
`AWS_ROLE_ARN`, `TF_STATE_BUCKET`, and, for this repository, `ALERT_EMAIL`.
The initial apply remains local because the OIDC roles do not exist beforehand.

## Routine deployment

- A push to `develop` selects the `hml` GitHub Environment.
- A push to `main` selects the `prod` GitHub Environment.
- The workflow initializes `infra-k8s/terraform.tfstate`, saves and uploads
  `tfplan`, and applies that exact file.
- Review the uploaded plan artifact and workflow logs. Never rerun an old saved
  plan after state or configuration changes.

## Verification

```powershell
aws eks describe-cluster --name soat-oficina-eks --region us-east-1
$hmlTargetGroupArn = terraform output -raw hml_target_group_arn
aws elbv2 describe-target-health --target-group-arn $hmlTargetGroupArn
kubectl get nodes
kubectl get pods -A
```

Also confirm that the SNS subscription is active, the CloudWatch dashboard and
alarms are present, and the AWS Budget is configured for `US$ 20` monthly with
actual-spend notifications at 50, 75, and 100 percent.

## Destruction

Use the manual `destroy` workflow, choose the GitHub Environment used for OIDC
approval, and type `DESTROY-soat-oficina`. The foundation is shared, so either
choice destroys the same root state and therefore both hml and prod foundation
resources. Tear down application, authentication, and database resources first.

For a local emergency teardown, inspect and apply only a saved destroy plan:

```powershell
terraform plan -destroy -var="github_owner=DevEgF" -var="alert_email=owner@example.com" -out=destroy.tfplan
terraform show destroy.tfplan
terraform apply destroy.tfplan
```

The bootstrap state bucket has `prevent_destroy` and is intentionally retained
for recovery and audit. Removing it is a separate, explicitly authorized action.
