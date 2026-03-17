function Sync-TCMDriftToMaester {
    <#
    .SYNOPSIS
        Bridge TCM drift detection to Maester's test framework — the north star.
    .DESCRIPTION
        Converts TCM active drifts into Maester-compatible drift test artifacts.
        This solves Maester's biggest open problem: persistent state management
        for configuration drift detection.

        TCM provides:
        - Server-side baseline storage (no local state management needed)
        - Automatic 6-hour monitoring cycles
        - Active drift tracking with property-level details

        This cmdlet bridges that into Maester by generating:
        1. Baseline JSON files (from TCM monitor baselines)
        2. Current JSON files (from TCM drift data showing actual values)
        3. A Pester test file that Maester can discover and run

        Maester's drift testing (PR #995) expects a folder structure like:
            drift/
              <suite-name>/
                baseline.json
                current.json

        This cmdlet generates exactly that, with TCM as the data source.

    .PARAMETER OutputPath
        The Maester drift folder where test artifacts will be written.
        Default: ./tests/Custom/drift
    .PARAMETER MonitorId
        Sync drifts from a specific monitor. If omitted, syncs all active drifts.
    .PARAMETER IncludeFixed
        Also include recently fixed drifts (for audit trail).
    .PARAMETER GenerateTest
        Generate a .Tests.ps1 file that Maester can discover. Default: true.
    .PARAMETER PassThru
        Also return the drift summary objects.
    .EXAMPLE
        # Sync all TCM drifts into Maester's drift folder
        Sync-TCMDriftToMaester -OutputPath "./maester-tests/Custom/drift"

        # Then run Maester normally:
        # Invoke-Maester -DriftRoot "./maester-tests/Custom/drift"
    .EXAMPLE
        # Sync and get summary
        $summary = Sync-TCMDriftToMaester -PassThru
        $summary | Where-Object { $_.DriftCount -gt 0 }
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath = './tests/Custom/drift',

        [string]$MonitorId,

        [switch]$IncludeFixed,

        [bool]$GenerateTest = $true,

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

    # Step 5: Generate Maester-compatible Pester test
    if ($GenerateTest) {
        $testFile = Join-Path $OutputPath 'TCM-Drift.Tests.ps1'
        $testContent = New-TCMDriftPesterTest -OutputPath $OutputPath
        Set-Content -Path $testFile -Value $testContent -Encoding utf8
        Write-Host "  📝 Generated Maester test: $testFile" -ForegroundColor DarkGray
    }

    # Summary
    $totalDrifts = ($summaries | Measure-Object -Property DriftCount -Sum).Sum
    Write-Host ''
    if ($totalDrifts -gt 0) {
        Write-Host "⚠️  $totalDrifts active drifts synced across $($summaries.Count) monitors." -ForegroundColor Yellow
        Write-Host '   Run Invoke-Maester to see drift results in the Maester report.' -ForegroundColor DarkGray
    }
    else {
        Write-Host "✅ No active drifts. All $($summaries.Count) monitors are clean." -ForegroundColor Green
    }

    if ($PassThru) { $summaries }
}


function New-TCMDriftPesterTest {
    <#
    .SYNOPSIS
        Internal: generates a Pester test file for Maester drift discovery.
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath
    )

    @'
<#
    .SYNOPSIS
        TCM-backed drift detection tests for Maester.

    .DESCRIPTION
        Auto-generated by EasyTCM (Sync-TCMDriftToMaester).
        Compares TCM monitor baselines against current state.
        TCM handles state management server-side — no local storage needed.

        Each subfolder represents a TCM monitor.
        baseline.json = desired state (from TCM monitor baseline)
        current.json  = actual state (baseline + drift deltas)
#>

BeforeDiscovery {
    $driftRoot = $PSScriptRoot
    $driftSuites = Get-ChildItem -Path $driftRoot -Directory -Filter "TCM-*"
}

Describe "TCM Configuration Drift: <_.Name>" -ForEach $driftSuites {
    BeforeAll {
        $suitePath = $_.FullName
        $baselinePath = Join-Path $suitePath "baseline.json"
        $currentPath  = Join-Path $suitePath "current.json"

        $baseline = if (Test-Path $baselinePath) {
            Get-Content $baselinePath -Raw | ConvertFrom-Json
        }
        $current = if (Test-Path $currentPath) {
            Get-Content $currentPath -Raw | ConvertFrom-Json
        }
    }

    It "should have baseline and current files" {
        $baselinePath | Should -Exist
        $currentPath  | Should -Exist
    }

    It "should have no configuration drift" {
        $baselineJson = $baseline | ConvertTo-Json -Depth 20
        $currentJson  = $current  | ConvertTo-Json -Depth 20

        if ($baselineJson -ne $currentJson) {
            # Build a human-readable diff summary
            $diffs = @()
            if ($baseline -is [array]) {
                for ($i = 0; $i -lt $baseline.Count; $i++) {
                    $b = $baseline[$i] | ConvertTo-Json -Depth 20
                    $c = if ($i -lt $current.Count) { $current[$i] | ConvertTo-Json -Depth 20 } else { "MISSING" }
                    if ($b -ne $c) {
                        $resName = $baseline[$i].displayName ?? "Resource $i"
                        $diffs += "  Drifted: $resName ($($baseline[$i].resourceType))"
                    }
                }
            }
            $diffSummary = $diffs -join "`n"
            "Configuration drift detected:`n$diffSummary" | Should -Be ""
        }
    }
}
'@
}
