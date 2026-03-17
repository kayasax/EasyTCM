function Get-TCMQuota {
    <#
    .SYNOPSIS
        Show current TCM API quota usage across monitors and snapshots.
    .DESCRIPTION
        Calculates and displays resource usage against TCM limits:
        - 30 monitors max
        - 800 monitored resources/day
        - 20,000 snapshot resources/month
        - 12 visible snapshot jobs
    .EXAMPLE
        Get-TCMQuota
    #>
    [CmdletBinding()]
    param()

    Write-Host 'Calculating TCM quota usage...' -ForegroundColor Cyan

    # Get monitors
    $monitors = Invoke-TCMGraphRequest -Endpoint 'configurationMonitors' -All
    if (-not $monitors) { $monitors = @() }

    # Calculate daily resource cost from monitors
    # Each monitor runs 4x/day; cost = resources * 4
    $dailyResourceUsage = 0
    $monitorDetails = foreach ($m in $monitors) {
        $baseline = $null
        try {
            $baseline = Invoke-TCMGraphRequest -Endpoint "configurationMonitors/$($m.id)/baseline"
        }
        catch { }

        $resourceCount = 0
        if ($baseline.resources) {
            $resourceCount = ($baseline.resources | Measure-Object).Count
        }

        $dailyCost = $resourceCount * 4
        $dailyResourceUsage += $dailyCost

        [PSCustomObject]@{
            MonitorName    = $m.displayName
            MonitorId      = $m.id
            Status         = $m.status
            Resources      = $resourceCount
            DailyQuotaCost = $dailyCost
        }
    }

    # Get snapshot jobs
    $snapshots = Invoke-TCMGraphRequest -Endpoint 'configurationSnapshotJobs' -All
    if (-not $snapshots) { $snapshots = @() }

    $snapshotResourceCount = ($snapshots | ForEach-Object {
        ($_.resources | Measure-Object).Count
    } | Measure-Object -Sum).Sum

    # Output
    Write-Host ''
    Write-Host '=== TCM Quota Dashboard ===' -ForegroundColor Yellow
    Write-Host ''

    # Monitors
    $monitorPct = [math]::Round(($monitors.Count / 30) * 100, 1)
    $monitorColor = if ($monitorPct -ge 80) { 'Red' } elseif ($monitorPct -ge 50) { 'Yellow' } else { 'Green' }
    Write-Host "  Monitors:            $($monitors.Count) / 30     ($monitorPct%)" -ForegroundColor $monitorColor

    # Daily resources
    $dailyPct = [math]::Round(($dailyResourceUsage / 800) * 100, 1)
    $dailyColor = if ($dailyPct -ge 80) { 'Red' } elseif ($dailyPct -ge 50) { 'Yellow' } else { 'Green' }
    Write-Host "  Daily Resources:     $dailyResourceUsage / 800   ($dailyPct%)" -ForegroundColor $dailyColor

    # Snapshot jobs
    $snapJobPct = [math]::Round(($snapshots.Count / 12) * 100, 1)
    $snapJobColor = if ($snapJobPct -ge 80) { 'Red' } elseif ($snapJobPct -ge 50) { 'Yellow' } else { 'Green' }
    Write-Host "  Snapshot Jobs:       $($snapshots.Count) / 12     ($snapJobPct%)" -ForegroundColor $snapJobColor

    # Monthly snapshot resources (approximate — we can only see current jobs)
    Write-Host "  Snapshot Resources:  ~$snapshotResourceCount / 20,000 (visible jobs only)" -ForegroundColor DarkGray

    Write-Host ''

    if ($monitorDetails) {
        Write-Host '  Monitor Breakdown:' -ForegroundColor DarkGray
        $monitorDetails | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor DarkGray
    }

    [PSCustomObject]@{
        MonitorCount         = $monitors.Count
        MonitorLimit         = 30
        DailyResourceUsage   = $dailyResourceUsage
        DailyResourceLimit   = 800
        SnapshotJobCount     = $snapshots.Count
        SnapshotJobLimit     = 12
        SnapshotResources    = $snapshotResourceCount
        MonthlySnapshotLimit = 20000
        Monitors             = $monitorDetails
    }
}
