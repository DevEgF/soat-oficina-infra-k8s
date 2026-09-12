[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$paths = @('ecr.tf', 'secrets.tf', 'pod-identity.tf') |
    ForEach-Object { Join-Path $PSScriptRoot "..\$_" }
$all = ($paths | ForEach-Object { Get-Content -LiteralPath $_ -Raw }) -join [Environment]::NewLine

if ($all -notmatch 'image_tag_mutability\s*=\s*"IMMUTABLE"') {
    throw 'ECR must be immutable'
}
if ($all -notmatch 'scan_on_push\s*=\s*true') {
    throw 'ECR scan_on_push missing'
}
if ($all -match 'output\s+"jwt_secret_value"') {
    throw 'secret value must never be output'
}
if ($all -notmatch 'ephemeral\s+"random_password"') {
    throw 'JWT generation must be ephemeral'
}
if ($all -notmatch 'secret_string_wo\s*=') {
    throw 'JWT secret write must be write-only'
}
if ($all -match '(?m)^\s*secret_string\s*=') {
    throw 'JWT secret would leak into Terraform state'
}
if ($all -match 'Resource\s*=\s*"\*"') {
    throw 'unscoped secret permission found'
}

Write-Output 'Registry and secret policy PASSED.'
