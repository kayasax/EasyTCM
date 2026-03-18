function Get-TCMMonitoringResult {
    <#
    .SYNOPSIS
        Retrieve monitoring cycle results for TCM monitors.
    .DESCRIPTION
        Returns the results of monitor runs, including cycle timing,
        run status, and drift counts. Use this to verify that your
        monitors are running and to check when the next cycle is expected.
        TCM monitors run every 6 hours on a fixed schedule (approximately
        6 AM, 12 PM, 6 PM, 12 AM UTC).
    .PARAMETER MonitorId
        Filter results for a specific monitor ID.
    .PARAMETER Last
        Return only the N most recent results. Default: all.
    .EXAMPLE
        Get-TCMMonitoringResult
        # Shows all monitoring cycle results
    .EXAMPLE
        Get-TCMMonitoringResult -MonitorId 'eca21d95-...' -Last 1
        # Shows the latest cycle result for a specific monitor
    .EXAMPLE
        Get-TCMMonitoringResult | Format-Table RunStatus, DriftsCount, StartedAt, CompletedAt, Duration
    #>
    [CmdletBinding()]
    param(
        [string]$MonitorId,

        [ValidateRange(1, 100)]
        [int]$Last
    )

    $endpoint = 'configurationMonitoringResults'
    $filters = @()
    if ($MonitorId) {
        $filters += "monitorId eq '$MonitorId'"
    }
    if ($filters.Count -gt 0) {
        $endpoint += '?$filter=' + ($filters -join ' and ')
    }

    $results = Invoke-TCMGraphRequest -Endpoint $endpoint -All

    if (-not $results) {
        Write-Host 'No monitoring results found. The first cycle may not have run yet.' -ForegroundColor Yellow
        return @()
    }

    $enriched = foreach ($r in $results) {
        $started = if ($r.runInitiationDateTime) { [DateTime]$r.runInitiationDateTime } else { $null }
        $completed = if ($r.runCompletionDateTime) { [DateTime]$r.runCompletionDateTime } else { $null }
        $duration = if ($started -and $completed) { $completed - $started } else { $null }

        # Estimate next run (6-hour fixed schedule)
        $nextRun = $null
        if ($completed) {
            $fixedSlots = @(0, 6, 12, 18) # UTC hours
            $completedUtc = $completed.ToUniversalTime()
            foreach ($slot in $fixedSlots) {
                $candidate = $completedUtc.Date.AddHours($slot)
                if ($candidate -gt $completedUtc) {
                    $nextRun = $candidate
                    break
                }
            }
            if (-not $nextRun) {
                $nextRun = $completedUtc.Date.AddDays(1).AddHours(0)
            }
        }

        [PSCustomObject]@{
            Id              = $r.id
            MonitorId       = $r.monitorId
            RunType         = $r.runType
            RunStatus       = $r.runStatus
            DriftsCount     = $r.driftsCount
            DriftsFixed     = $r.driftsFixed
            StartedAt       = $started
            CompletedAt     = $completed
            Duration        = $duration
            NextRunEstimate = $nextRun
        }
    }

    # Sort by most recent first
    $enriched = $enriched | Sort-Object CompletedAt -Descending

    if ($Last) {
        $enriched = $enriched | Select-Object -First $Last
    }

    $enriched
}
