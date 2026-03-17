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

        if (-not $Baseline -or -not $Baseline.resources) {
            throw 'A baseline with at least one resource is required. Use ConvertTo-TCMBaseline or provide a JSON file.'
        }

        $resourceCount = $Baseline.resources.Count
        Write-Host "Creating monitor '$DisplayName' with $resourceCount resources..." -ForegroundColor Cyan

        # Quota check: 800 resources/day across all monitors, each runs 4x/day
        $dailyCost = $resourceCount * 4
        Write-Host "  Daily resource usage: $dailyCost / 800 quota" -ForegroundColor DarkGray

        $body = @{
            displayName = $DisplayName
            baseline    = $Baseline
        }
        if ($Description) { $body.description = $Description }
        if ($Parameters)  { $body.parameters = $Parameters }

        $monitor = Invoke-TCMGraphRequest -Endpoint 'configurationMonitors' -Method POST -Body $body

        Write-Host "Monitor created (Id: $($monitor.id), Status: $($monitor.status))" -ForegroundColor Green
        Write-Host "  Runs every 6 hours at fixed GMT times: 6 AM, 12 PM, 6 PM, 12 AM" -ForegroundColor DarkGray
        Write-Host "  Use Get-TCMDrift to check for detected drifts." -ForegroundColor DarkGray

        $monitor
    }
}
