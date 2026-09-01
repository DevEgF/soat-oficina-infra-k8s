[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '..\scripts\aws-cost-estimate.py'

if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw 'scripts/aws-cost-estimate.py does not exist'
}

$json = & python $scriptPath --json
if ($LASTEXITCODE -ne 0) {
    throw 'AWS cost estimate script failed'
}

$estimate = $json | ConvertFrom-Json
if ([decimal]$estimate.totals.'40h' -gt [decimal]8) {
    throw "40-hour estimate exceeds USD 8: $($estimate.totals.'40h')"
}
if ([decimal]$estimate.totals.'730h' -lt [decimal]140 -or
    [decimal]$estimate.totals.'730h' -gt [decimal]150) {
    throw "730-hour estimate is outside USD 140-150: $($estimate.totals.'730h')"
}

Write-Output "Cost estimate PASSED: 40h=$($estimate.totals.'40h') 730h=$($estimate.totals.'730h')"
