[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Kubeconfig,
    [Parameter(Mandatory)]
    [ValidatePattern('^arn:aws:eks:us-east-1:[0-9]{12}:cluster/soat-oficina-eks$')]
    [string]$ClusterArn
)

$ErrorActionPreference = 'Stop'
$configPath = (Resolve-Path -LiteralPath $Kubeconfig).Path
$contextName = & kubectl --kubeconfig $configPath config current-context
if ($LASTEXITCODE -ne 0 -or $contextName.Trim() -ne $ClusterArn) {
    throw 'The explicit kubeconfig must select the expected EKS cluster ARN.'
}
$configJson = & kubectl --kubeconfig $configPath --context $ClusterArn config view --minify -o json
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect the selected kubeconfig context.' }
$config = ($configJson -join "`n") | ConvertFrom-Json
if ($config.contexts[0].context.cluster -ne $ClusterArn) {
    throw 'The selected context is not bound to the expected EKS cluster.'
}
& kubectl --kubeconfig $configPath --context $ClusterArn wait --for=condition=Established crd/secretproviderclasses.secrets-store.csi.x-k8s.io --timeout=120s
if ($LASTEXITCODE -ne 0) { throw 'Secrets Store CSI must be ready before namespace bootstrap.' }
& kubectl --kubeconfig $configPath --context $ClusterArn apply -f (Join-Path $PSScriptRoot '../kubernetes/app-bootstrap.yaml')
if ($LASTEXITCODE -ne 0) { throw 'Application namespace bootstrap failed.' }
