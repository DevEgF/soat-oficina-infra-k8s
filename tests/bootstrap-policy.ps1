[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$source = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\bootstrap\main.tf') -Raw

if ($source -notmatch 'aws_s3_bucket_versioning') {
    throw 'versioning missing'
}
if ($source -notmatch 'aws_s3_bucket_server_side_encryption_configuration') {
    throw 'encryption missing'
}
if ($source -notmatch 'aws_s3_bucket_public_access_block') {
    throw 'public access block missing'
}

Write-Output 'Terraform state bootstrap policy PASSED.'
