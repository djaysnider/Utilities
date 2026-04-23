<#
.SYNOPSIS
    Connects to Azure Government, reads a CSV list of Azure VMs,
    and reports average and peak CPU utilization for the previous month.

.DESCRIPTION
    Expected CSV columns:
        SubscriptionId,ResourceGroupName,VMName

    Example:
        SubscriptionId,ResourceGroupName,VMName
        11111111-1111-1111-1111-111111111111,rg-prod-app,vm-app-01
        22222222-2222-2222-2222-222222222222,rg-prod-db,vm-db-01

    Output:
        Writes results to screen and exports a CSV file.

.NOTES
    Requires:
        Az.Accounts
        Az.Compute
        Az.Monitor
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ServerListCsv,

    [Parameter(Mandatory = $false)]
    [string]$OutputCsv = ".\AzureGov-PreviousMonth-CPUReport.csv",

    [Parameter(Mandatory = $false)]
    [switch]$UseDeviceAuthentication
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-RequiredModule {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Get-Module -ListAvailable -Name $Name)) {
        throw "Required module '$Name' is not installed. Install it with: Install-Module $Name -Scope CurrentUser"
    }
}

function Get-PreviousMonthWindowUtc {
    $now = Get-Date
    $firstDayOfCurrentMonth = Get-Date -Year $now.Year -Month $now.Month -Day 1 -Hour 0 -Minute 0 -Second 0
    $startLocal = $firstDayOfCurrentMonth.AddMonths(-1)
    $endLocal = $firstDayOfCurrentMonth.AddSeconds(-1)

    [PSCustomObject]@{
        StartLocal = $startLocal
        EndLocal   = $endLocal
        StartUtc   = $startLocal.ToUniversalTime()
        EndUtc     = $endLocal.ToUniversalTime()
        Label      = $startLocal.ToString("yyyy-MM")
    }
}

function Get-OverallCpuStats {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceId,

        [Parameter(Mandatory = $true)]
        [datetime]$StartTimeUtc,

        [Parameter(Mandatory = $true)]
        [datetime]$EndTimeUtc
    )

    # 1-hour grain gives a practical balance between fidelity and API volume.
    $metric = Get-AzMetric `
        -ResourceId $ResourceId `
        -MetricName "Percentage CPU" `
        -StartTime $StartTimeUtc `
        -EndTime $EndTimeUtc `
        -TimeGrain 01:00:00 `
        -DetailedOutput

    if (-not $metric -or -not $metric.Data) {
        return [PSCustomObject]@{
            AverageCpu = $null
            PeakCpu    = $null
            Samples    = 0
        }
    }

    $avgSamples = @(
        $metric.Data |
        Where-Object { $null -ne $_.Average } |
        Select-Object -ExpandProperty Average
    )

    $maxSamples = @(
        $metric.Data |
        Where-Object { $null -ne $_.Maximum } |
        Select-Object -ExpandProperty Maximum
    )

    $overallAverage = $null
    if ($avgSamples.Count -gt 0) {
        $overallAverage = [math]::Round((($avgSamples | Measure-Object -Average).Average), 2)
    }

    $overallPeak = $null
    if ($maxSamples.Count -gt 0) {
        $overallPeak = [math]::Round((($maxSamples | Measure-Object -Maximum).Maximum), 2)
    }

    [PSCustomObject]@{
        AverageCpu = $overallAverage
        PeakCpu    = $overallPeak
        Samples    = [math]::Max($avgSamples.Count, $maxSamples.Count)
    }
}

try {
    Test-RequiredModule -Name "Az.Accounts"
    Test-RequiredModule -Name "Az.Compute"
    Test-RequiredModule -Name "Az.Monitor"

    if (-not (Test-Path -LiteralPath $ServerListCsv)) {
        throw "Input CSV not found: $ServerListCsv"
    }

    $servers = Import-Csv -LiteralPath $ServerListCsv

    if (-not $servers -or $servers.Count -eq 0) {
        throw "The input CSV is empty."
    }

    $requiredColumns = @("SubscriptionId", "ResourceGroupName", "VMName")
    foreach ($col in $requiredColumns) {
        if ($servers[0].PSObject.Properties.Name -notcontains $col) {
            throw "Input CSV must contain column '$col'."
        }
    }

    Write-Host "Connecting to Azure Government..." -ForegroundColor Cyan
    if ($UseDeviceAuthentication) {
        Connect-AzAccount -Environment AzureUSGovernment -UseDeviceAuthentication | Out-Null
    }
    else {
        Connect-AzAccount -Environment AzureUSGovernment | Out-Null
    }

    $window = Get-PreviousMonthWindowUtc

    Write-Host "Reporting window:" -ForegroundColor Cyan
    Write-Host ("  Local: {0} through {1}" -f $window.StartLocal, $window.EndLocal)
    Write-Host ("  UTC:   {0} through {1}" -f $window.StartUtc, $window.EndUtc)

    $results = New-Object System.Collections.Generic.List[object]
    $subscriptionCache = @{}

    foreach ($server in $servers) {
        $subscriptionId = $server.SubscriptionId.Trim()
        $resourceGroup  = $server.ResourceGroupName.Trim()
        $vmName         = $server.VMName.Trim()

        Write-Host ""
        Write-Host "Processing $vmName in $resourceGroup / $subscriptionId ..." -ForegroundColor Yellow

        try {
            if (-not $subscriptionCache.ContainsKey($subscriptionId)) {
                Set-AzContext -SubscriptionId $subscriptionId | Out-Null
                $subscriptionCache[$subscriptionId] = $true
            }
            else {
                Set-AzContext -SubscriptionId $subscriptionId | Out-Null
            }

            $vm = Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName -Status -ErrorAction Stop

            $stats = Get-OverallCpuStats `
                -ResourceId $vm.Id `
                -StartTimeUtc $window.StartUtc `
                -EndTimeUtc $window.EndUtc

            $results.Add([PSCustomObject]@{
                Month             = $window.Label
                SubscriptionId    = $subscriptionId
                ResourceGroupName = $resourceGroup
                VMName            = $vmName
                Location          = $vm.Location
                PowerState        = ($vm.Statuses | Where-Object { $_.Code -like "PowerState/*" } | Select-Object -ExpandProperty DisplayStatus -First 1)
                AverageCpuPct     = $stats.AverageCpu
                PeakCpuPct        = $stats.PeakCpu
                SampleCount       = $stats.Samples
                Status            = "OK"
                Error             = $null
            })
        }
        catch {
            $results.Add([PSCustomObject]@{
                Month             = $window.Label
                SubscriptionId    = $subscriptionId
                ResourceGroupName = $resourceGroup
                VMName            = $vmName
                Location          = $null
                PowerState        = $null
                AverageCpuPct     = $null
                PeakCpuPct        = $null
                SampleCount       = 0
                Status            = "Failed"
                Error             = $_.Exception.Message
            })

            Write-Warning "Failed to process $vmName: $($_.Exception.Message)"
        }
    }

    $results |
        Sort-Object SubscriptionId, ResourceGroupName, VMName |
        Tee-Object -Variable finalResults |
        Format-Table -AutoSize

    $finalResults |
        Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding UTF8

    Write-Host ""
    Write-Host "Report exported to: $OutputCsv" -ForegroundColor Green
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}