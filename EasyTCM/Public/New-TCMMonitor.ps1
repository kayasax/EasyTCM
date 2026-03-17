function New-TCMMonitor {
    <#
    .SYNOPSIS
        Create a configuration monitor that detects drift every 6 hours.
    .DESCRIPTION
        Creates a TCM monitor with a baseline. The monitor runs every 6 hours (fixed)
        and compares the current tenant config against the baseline, reporting drifts.
    .PARAMETER DisplayName
        A friendly name for the monitor.
    .PARAMETER Description
        Optional description.
    .PARAMETER Baseline
        The baseline object (from ConvertTo-TCMBaseline or manually constructed).
    .PARAMETER BaselinePath
        Path to a JSON file containing the baseline.
    .PARAMETER Parameters
        Optional key-value parameters (e.g., TenantId, FQDN) used in the baseline.
    .EXAMPLE
        New-TCMMonitor -DisplayName "Entra Monitor" -Baseline $baseline
    .EXAMPLE
        New-TCMMonitor -DisplayName "Exchange Monitor" -BaselinePath "./baselines/exchange.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName,

        [string]$Description,

        [Parameter(ValueFromPipeline, ParameterSetName = 'Object')]
        [hashtable]$Baseline,

        [Parameter(ParameterSetName = 'File')]
        [string]$BaselinePath,

        [hashtable]$Parameters
    )

    process {
        if ($BaselinePath) {
            if (-not (Test-Path $BaselinePath)) {
                throw "Baseline file not found: $BaselinePath"
            }
            $Baseline = Get-Content $BaselinePath -Raw | ConvertFrom-Json -AsHashtable
        }

        if (-not $Baseline -or (-not $Baseline.resources -and -not $Baseline.Resources)) {
            throw 'A baseline with at least one resource is required. Use ConvertTo-TCMBaseline or provide a JSON file.'
        }

        # Support both camelCase and PascalCase resource keys
        $resources = if ($Baseline.Resources) { $Baseline.Resources } else { $Baseline.resources }
        $resourceCount = @($resources).Count
        Write-Host "Creating monitor '$DisplayName' with $resourceCount resources..." -ForegroundColor Cyan

        # Quota impact: show this monitor's cost + existing monitors
        $dailyCost = $resourceCount * 4
        $existingMonitors = @()
        try { $existingMonitors = @(Get-TCMMonitor) } catch { }
        $existingDailyCost = ($existingMonitors | ForEach-Object {
            # Estimate: we don't always know resource count, but count what we can
            if ($_.baseline -and $_.baseline.resources) { $_.baseline.resources.Count * 4 }
        } | Measure-Object -Sum).Sum

        $totalDaily = $existingDailyCost + $dailyCost
        $quotaPercent = [math]::Round(($totalDaily / 800) * 100, 1)
        $color = if ($quotaPercent -gt 80) { 'Red' } elseif ($quotaPercent -gt 50) { 'Yellow' } else { 'Green' }

        Write-Host "  This monitor: $dailyCost resources/day" -ForegroundColor DarkGray
        Write-Host "  Total after creation: ~$totalDaily / 800 daily quota ($quotaPercent%)" -ForegroundColor $color

        if ($quotaPercent -gt 100) {
            Write-Warning "OVER QUOTA! Total monitored resources ($totalDaily/day) exceeds the 800/day limit. TCM will throttle or fail. Use ConvertTo-TCMBaseline -Profile SecurityCritical to reduce."
        }
        elseif ($quotaPercent -gt 80) {
            Write-Warning "Nearing quota limit ($quotaPercent%). Consider using ConvertTo-TCMBaseline -Profile SecurityCritical."
        }

        $body = @{
            displayName = $DisplayName
            baseline    = $Baseline
        }
        if ($Description) { $body.description = $Description }
        if ($Parameters)  { $body.parameters = $Parameters }

        $monitor = Invoke-TCMGraphRequest -Endpoint 'configurationMonitors' -Method POST -Body $body

        if (-not $monitor) {
            return
        }

        $monId = if ($monitor -is [System.Collections.IDictionary]) { $monitor['id'] } else { $monitor.id }
        $monStat = if ($monitor -is [System.Collections.IDictionary]) { $monitor['status'] } else { $monitor.status }

        Write-Host "Monitor created (Id: $monId, Status: $monStat)" -ForegroundColor Green
        Write-Host "  Runs every 6 hours at fixed GMT times: 6 AM, 12 PM, 6 PM, 12 AM" -ForegroundColor DarkGray
        Write-Host "  Use Get-TCMDrift to check for detected drifts." -ForegroundColor DarkGray

        $monitor
    }
}
