function Watch-TCMDrift {
    <#
    .SYNOPSIS
        Single command to check your tenant for drift — console, HTML report, or Maester.
    .DESCRIPTION
        The daily command for TCM monitoring. Checks all monitors for active drift
        and presents results in the format you choose:

        • No switch:     Console summary (quick check)
        • -Report:       HTML report with admin portal links
        • -Maester:      Sync to Maester + run drift tests
        • -CompareBaseline: Also detect new/deleted resources (uses quota)

    .PARAMETER Report
        Generate an HTML drift report with admin portal deep links.
    .PARAMETER Maester
        Sync drift to Maester format and run Invoke-Maester on the drift folder.
    .PARAMETER CompareBaseline
        Also detect new/deleted resources not tracked by the monitor.
        Uses a snapshot (quota impact) but results are cached for 1 hour.
    .PARAMETER MonitorId
        Check a specific monitor. If omitted, checks all monitors.
    .PARAMETER PassThru
        Return the drift objects for pipeline processing.
    .EXAMPLE
        # Quick console check
        Watch-TCMDrift

    .EXAMPLE
        # Full HTML report
        Watch-TCMDrift -Report

    .EXAMPLE
        # Maester integration with baseline comparison
        Watch-TCMDrift -Maester -CompareBaseline

    .EXAMPLE
        # Pipeline: get drifted resource details
        Watch-TCMDrift -PassThru | Where-Object { $_.DriftedPropertyCount -gt 0 }
    #>
    [CmdletBinding()]
    param(
        [switch]$Report,
        [switch]$Maester,
        [switch]$CompareBaseline,
        [string]$MonitorId,
        [switch]$PassThru
    )

    # ── Resolve mode ────────────────────────────────────────────────
    if ($Report) {
        # HTML report mode
        $reportParams = @{}
        if ($MonitorId) { $reportParams.MonitorId = $MonitorId }
        if ($CompareBaseline) { $reportParams.CompareBaseline = $true }
        $result = Export-TCMDriftReport @reportParams
        if ($PassThru) { return $result }
        return
    }

    if ($Maester) {
        # Maester sync + run mode
        $syncParams = @{}
        if ($MonitorId) { $syncParams.MonitorId = $MonitorId }
        if ($CompareBaseline) { $syncParams.CompareBaseline = $true }
        Sync-TCMDriftToMaester @syncParams

        # Resolve drift folder
        $driftPath = if ($env:MAESTER_TESTS_PATH) {
            Join-Path $env:MAESTER_TESTS_PATH 'Drift'
        } else {
            './tests/Maester/Drift'
        }
        if (Test-Path $driftPath) {
            Write-Host ''
            Invoke-Maester -Path $driftPath
        }
        return
    }

    # ── Console summary mode (default) ─────────────────────────────
    Write-Host ''
    Write-Host '🔍 Checking for configuration drift...' -ForegroundColor Cyan
    Write-Host ''

    $driftParams = @{ Status = 'active' }
    if ($MonitorId) { $driftParams.MonitorId = $MonitorId }
    $drifts = @(Get-TCMDrift @driftParams)

    $monitors = if ($MonitorId) {
        @(Get-TCMMonitor -Id $MonitorId)
    } else {
        @(Get-TCMMonitor)
    }

    if ($drifts.Count -eq 0) {
        Write-Host "  ✅ No active drift across $($monitors.Count) monitor(s)." -ForegroundColor Green
        Write-Host "     TCM checks every 6 hours automatically." -ForegroundColor DarkGray
    }
    else {
        Write-Host "  ⚠️  $($drifts.Count) active drift(s) detected!" -ForegroundColor Yellow
        Write-Host ''

        # Group by resource type
        $grouped = $drifts | Group-Object -Property ResourceType
        foreach ($group in $grouped) {
            $shortType = ($group.Name -split '\.')[-1]
            Write-Host "  $shortType ($($group.Count)):" -ForegroundColor White
            foreach ($d in $group.Group) {
                $propCount = $d.DriftedPropertyCount
                Write-Host "    • $($d.ResourceDisplay) — $propCount changed propert$(if ($propCount -eq 1) {'y'} else {'ies'})" -ForegroundColor Yellow
                if ($d.DriftedProperties) {
                    foreach ($dp in $d.DriftedProperties | Select-Object -First 3) {
                        Write-Host "      $($dp.propertyName): $($dp.baselineValue) → $($dp.currentValue)" -ForegroundColor DarkGray
                    }
                    if ($d.DriftedProperties.Count -gt 3) {
                        Write-Host "      ... and $($d.DriftedProperties.Count - 3) more" -ForegroundColor DarkGray
                    }
                }
            }
            Write-Host ''
        }
    }

    # Optional: baseline comparison
    if ($CompareBaseline) {
        Write-Host '  🔗 Checking for untracked resources...' -ForegroundColor Cyan
        $compareParams = @{}
        if ($MonitorId) { $compareParams.MonitorId = $MonitorId }
        $comparison = Compare-TCMBaseline @compareParams
        if ($comparison.HasDrift) {
            Write-Host "  ⚠️  $($comparison.NewCount) new, $($comparison.DeletedCount) deleted resource(s) not in baseline." -ForegroundColor Yellow
            Write-Host "     Run Update-TCMBaseline to adopt approved changes." -ForegroundColor DarkGray
        }
        else {
            Write-Host "  ✅ All resources are tracked. Baseline is up to date." -ForegroundColor Green
        }
        Write-Host ''
    }

    # Hints
    if (-not $Report -and -not $Maester) {
        Write-Host '  Commands:' -ForegroundColor DarkGray
        Write-Host '    Watch-TCMDrift -Report           # detailed HTML report' -ForegroundColor DarkGray
        Write-Host '    Watch-TCMDrift -Maester           # Maester test results' -ForegroundColor DarkGray
        Write-Host '    Watch-TCMDrift -CompareBaseline   # find untracked resources' -ForegroundColor DarkGray
        if ($drifts.Count -gt 0) {
            Write-Host '    Update-TCMBaseline               # accept current state as new baseline' -ForegroundColor DarkGray
        }
        Write-Host ''
    }

    if ($PassThru) { $drifts }
}
