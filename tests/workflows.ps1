$ErrorActionPreference = 'Stop'

$ci = Get-Content .github/workflows/ci.yml -Raw
$deploy = Get-Content .github/workflows/deploy.yml -Raw
$destroy = Get-Content .github/workflows/destroy.yml -Raw
if ($ci -notmatch 'pull_request:') { throw 'CI must run on pull requests' }
if ($ci -notmatch '(?m)^name:\s*terraform\s*$') { throw 'CI workflow name must expose terraform checks' }
if ($ci -notmatch '(?m)^\s+validate:\s*$') { throw 'terraform / validate check is missing' }
if ($ci -notmatch '(?m)^\s+security:\s*$') { throw 'terraform / security check is missing' }
if ($deploy -notmatch 'id-token:\s*write') { throw 'deploy must request OIDC token' }
if ($deploy -notmatch 'terraform apply -input=false tfplan') { throw 'deploy must apply the saved plan' }
if ($destroy -notmatch 'workflow_dispatch:') { throw 'destroy must be manual' }
if ($destroy -notmatch 'DESTROY-soat-oficina') { throw 'destroy confirmation missing' }
if ($destroy -notmatch 'terraform apply -input=false destroy\.tfplan') { throw 'destroy must apply the saved plan' }

$all = $ci, $deploy, $destroy -join "`n"
$uses = [regex]::Matches($all, '(?m)^\s*uses:\s*(?<reference>\S+)')
foreach ($use in $uses) {
    if ($use.Groups['reference'].Value -notmatch '@[0-9a-f]{40}$') {
        throw "action is not pinned by full SHA: $($use.Groups['reference'].Value)"
    }
}
