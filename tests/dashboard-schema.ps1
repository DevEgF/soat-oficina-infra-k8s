$ErrorActionPreference = 'Stop'

$dashboard = Get-Content observability.tf -Raw
$alarmWidgetWithMetrics = '(?s)title\s*=\s*"Environment alarm status".*?metrics\s*=\s*\[.*?UnHealthyHostCount.*?annotations\s*='

if ($dashboard -notmatch $alarmWidgetWithMetrics) {
    throw 'alarm dashboard widget must include UnHealthyHostCount metrics before its alarm annotations'
}
