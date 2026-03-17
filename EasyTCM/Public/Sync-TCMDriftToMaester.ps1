function Sync-TCMDriftToMaester {
    <#
    .SYNOPSIS
        Bridge TCM drift detection to Maester's built-in drift tests (MT.1060).
    .DESCRIPTION
        Generates the drift folder structure that Maester's MT.1060 natively discovers.
        No Maester modifications needed — MT.1060 (shipped in Maester v2.0+) auto-discovers
        drift suites as subfolders containing baseline.json and current.json.

        TCM provides server-side baseline storage and automatic 6-hour monitoring,
        so there's no local state to manage. This cmdlet simply materializes the
        TCM drift state into files that Maester already knows how to test.

        Generated structure:
            <OutputPath>/
              TCM-<MonitorName>/
                baseline.json       # Desired state (from TCM monitor baseline)
                current.json        # Actual state (baseline + drift deltas)
                settings.json       # Optional MT.1060 settings

        Then just run: Invoke-Maester
        MT.1060 picks up the TCM drift suites automatically.

    .PARAMETER OutputPath
        The folder where drift suites will be written. Should be under or alongside
        your Maester test root so MT.1060 discovers them.
        Default: ./tests/Maester/Drift
    .PARAMETER MonitorId
        Sync drifts from a specific monitor. If omitted, syncs all active drifts.
    .PARAMETER IncludeFixed
        Also include recently fixed drifts (for audit trail).
    .PARAMETER PassThru
        Also return the drift summary objects.
    .EXAMPLE
        # Sync all TCM drifts — then run Maester normally
        Sync-TCMDriftToMaester
        Invoke-Maester

    .EXAMPLE
        # Sync to a custom path and get summary
        $summary = Sync-TCMDriftToMaester -OutputPath "./my-tests/drift" -PassThru
        $summary | Where-Object { $_.DriftCount -gt 0 }
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath = './tests/Maester/Drift',

        [string]$MonitorId,

        [switch]$IncludeFixed,

        [switch]$PassThru
    )

    Write-Host '🔗 Syncing TCM drifts to Maester format...' -ForegroundColor Cyan

    # Step 1: Get monitors and their baselines
    $monitors = if ($MonitorId) {
        @(Get-TCMMonitor -Id $MonitorId -IncludeBaseline)
    }
    else {
        $allMonitors = Get-TCMMonitor
        if (-not $allMonitors) {
            Write-Warning 'No TCM monitors found. Create monitors first with New-TCMMonitor.'
            return
        }
        foreach ($m in $allMonitors) {
            Get-TCMMonitor -Id $m.id -IncludeBaseline
        }
    }

    # Step 2: Get active drifts
    $driftParams = @{ Status = 'active' }
    if ($MonitorId) { $driftParams.MonitorId = $MonitorId }
    $drifts = Get-TCMDrift @driftParams

    if ($IncludeFixed) {
        $fixedDrifts = Get-TCMDrift -Status fixed
        if ($MonitorId) { $fixedDrifts = $fixedDrifts | Where-Object { $_.MonitorId -eq $MonitorId } }
        $drifts = @($drifts) + @($fixedDrifts)
    }

    # Step 3: Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    # Step 4: Generate per-monitor drift suites
    $summaries = [System.Collections.Generic.List[object]]::new()

    foreach ($monitor in $monitors) {
        $monitorName = ($monitor.displayName -replace '[^\w\-]', '_')
        $suitePath = Join-Path $OutputPath "TCM-$monitorName"

        if (-not (Test-Path $suitePath)) {
            New-Item -Path $suitePath -ItemType Directory -Force | Out-Null
        }

        # Build "baseline" from monitor's baseline
        $baselineData = @{}
        if ($monitor.baseline -and $monitor.baseline.resources) {
            foreach ($res in $monitor.baseline.resources) {
                $key = "$($res.resourceType)|$($res.displayName)"
                $baselineData[$key] = @{
                    resourceType = $res.resourceType
                    displayName  = $res.displayName
                    properties   = $res.properties
                }
            }
        }

        # Build "current" by applying drift deltas to baseline
        $currentData = $baselineData.Clone()
        $monitorDrifts = @($drifts | Where-Object { $_.MonitorId -eq $monitor.id })

        foreach ($drift in $monitorDrifts) {
            $key = "$($drift.ResourceType)|$($drift.ResourceDisplay)"

            if ($currentData.ContainsKey($key)) {
                $current = $currentData[$key]
                # Override drifted properties with current (actual) values
                foreach ($dp in $drift.DriftedProperties) {
                    $current.properties[$dp.propertyName] = $dp.currentValue
                }
            }
            else {
                # Drift on a resource not in our baseline copy — create entry from drift data
                $props = @{}
                foreach ($dp in $drift.DriftedProperties) {
                    $props[$dp.propertyName] = $dp.currentValue
                }
                $currentData[$key] = @{
                    resourceType = $drift.ResourceType
                    displayName  = $drift.ResourceDisplay
                    properties   = $props
                }
            }
        }

        # Write baseline.json and current.json
        $baselineFile = Join-Path $suitePath 'baseline.json'
        $currentFile  = Join-Path $suitePath 'current.json'

        $baselineData.Values | ConvertTo-Json -Depth 20 | Set-Content -Path $baselineFile -Encoding utf8
        $currentData.Values  | ConvertTo-Json -Depth 20 | Set-Content -Path $currentFile -Encoding utf8

        # Write settings.json for MT.1060 (optional metadata)
        $settingsFile = Join-Path $suitePath 'settings.json'
        @{
            Source    = 'EasyTCM'
            MonitorId = $monitor.id
            SyncedAt  = (Get-Date -Format 'o')
        } | ConvertTo-Json | Set-Content -Path $settingsFile -Encoding utf8

        $summary = [PSCustomObject]@{
            MonitorName   = $monitor.displayName
            MonitorId     = $monitor.id
            SuitePath     = $suitePath
            BaselineFile  = $baselineFile
            CurrentFile   = $currentFile
            ResourceCount = $baselineData.Count
            DriftCount    = $monitorDrifts.Count
            DriftedProps  = ($monitorDrifts | ForEach-Object { $_.DriftedPropertyCount } | Measure-Object -Sum).Sum
        }
        $summaries.Add($summary)

        $driftIcon = if ($monitorDrifts.Count -gt 0) { '⚠️' } else { '✅' }
        Write-Host "  $driftIcon $($monitor.displayName): $($monitorDrifts.Count) drifts across $($baselineData.Count) resources" -ForegroundColor $(if ($monitorDrifts.Count -gt 0) { 'Yellow' } else { 'Green' })
    }

    # Summary
    $totalDrifts = ($summaries | Measure-Object -Property DriftCount -Sum).Sum
    Write-Host ''
    if ($totalDrifts -gt 0) {
        Write-Host "⚠️  $totalDrifts active drifts synced across $($summaries.Count) monitors." -ForegroundColor Yellow
        Write-Host '   Run Invoke-Maester — MT.1060 will pick up the TCM drift suites automatically.' -ForegroundColor DarkGray
    }
    else {
        Write-Host "✅ No active drifts. All $($summaries.Count) monitors are clean." -ForegroundColor Green
    }

    if ($PassThru) { $summaries }
}
