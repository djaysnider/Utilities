param(
    [string]$AssignmentPrefix = "tag-governance",
    [string]$OutputPath = ".\tag-policy-deviations.csv"
)

$ErrorActionPreference = "Stop"

$templatePath = Join-Path $PSScriptRoot "..\queries\tag_policy_deviations.kql"
$query = Get-Content -Raw -Path $templatePath
$query = $query.Replace("{ASSIGNMENT_PREFIX}", $AssignmentPrefix)

Write-Host "Running Azure Resource Graph query for assignment prefix '$AssignmentPrefix'..."
$result = az graph query -q $query --first 5000 | ConvertFrom-Json

if ($null -eq $result.data -or $result.data.Count -eq 0) {
    Write-Host "No tag policy deviations found."
    return
}

$result.data | Export-Csv -Path $OutputPath -NoTypeInformation
Write-Host "Wrote deviation report to $OutputPath"
