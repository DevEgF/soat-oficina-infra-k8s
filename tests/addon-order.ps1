$ErrorActionPreference = 'Stop'

$addons = Get-Content addons.tf -Raw
$nodeDependentAddons = 'metrics_server', 'cloudwatch', 'coredns'

foreach ($addon in $nodeDependentAddons) {
    $resourceBlock = '(?s)resource\s+"aws_eks_addon"\s+"' + $addon + '"\s+\{(?:(?!\r?\nresource\s).)*depends_on\s*=\s*\[module\.eks\]'
    if ($addons -notmatch $resourceBlock) {
        throw "$addon must wait for the EKS module, including its managed node group"
    }
}
