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
                TCM-Drift.Tests.ps1 # Pester test discovered by Invoke-Maester

        Then just run: Invoke-Maester
        MT.1060 picks up the TCM drift suites automatically.

    .PARAMETER OutputPath
        The folder where drift suites will be written. Should be under or alongside
        your Maester test root so MT.1060 discovers them.
        Default priority: $env:MAESTER_TESTS_PATH/Drift → ./tests/Maester/Drift
    .PARAMETER MonitorId
        Sync drifts from a specific monitor. If omitted, syncs all active drifts.
    .PARAMETER IncludeFixed
        Also include recently fixed drifts (for audit trail).
    .PARAMETER CompareBaseline
        Also detect new/deleted resources by running Compare-TCMBaseline.
        This takes a fresh snapshot (uses quota) and generates an additional
        Maester test suite for baseline drift. Without this flag, only property
        drifts on existing monitored resources are synced.
    .PARAMETER PassThru
        Also return the drift summary objects.
    .EXAMPLE
        # Sync all TCM drifts — then run Maester normally
        Sync-TCMDriftToMaester
        Invoke-Maester

    .EXAMPLE
        # Full sync including new/deleted resources
        Sync-TCMDriftToMaester -CompareBaseline
        Invoke-Maester

    .EXAMPLE
        # Sync to a custom path and get summary
        $summary = Sync-TCMDriftToMaester -OutputPath "./my-tests/drift" -PassThru
        $summary | Where-Object { $_.DriftCount -gt 0 }
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath,

        [string]$MonitorId,

        [switch]$IncludeFixed,

        [switch]$CompareBaseline,

        [switch]$PassThru
    )

    # Resolve OutputPath: explicit param → env var → default
    if (-not $OutputPath) {
        $OutputPath = if ($env:MAESTER_TESTS_PATH) {
            Join-Path $env:MAESTER_TESTS_PATH 'Drift'
        } else {
            './tests/Maester/Drift'
        }
    }

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
        $monDisplayName = if ($monitor -is [System.Collections.IDictionary]) { $monitor['displayName'] } else { $monitor.displayName }
        $monId = if ($monitor -is [System.Collections.IDictionary]) { $monitor['id'] } else { $monitor.id }
        $monBaseline = if ($monitor -is [System.Collections.IDictionary]) { $monitor['baseline'] } else { $monitor.baseline }

        $monitorName = ($monDisplayName -replace '[^\w\-]', '_')
        $suitePath = Join-Path $OutputPath "TCM-$monitorName"

        if (-not (Test-Path $suitePath)) {
            New-Item -Path $suitePath -ItemType Directory -Force | Out-Null
        }

        # Build "baseline" from monitor's baseline
        $baselineData = @{}
        $baselineResources = if ($monBaseline -is [System.Collections.IDictionary]) { $monBaseline['resources'] } elseif ($monBaseline) { $monBaseline.resources } else { $null }
        if ($baselineResources) {
            foreach ($res in $baselineResources) {
                $resType = if ($res -is [System.Collections.IDictionary]) { $res['resourceType'] } else { $res.resourceType }
                $resDn = if ($res -is [System.Collections.IDictionary]) { $res['displayName'] } else { $res.displayName }
                $resProps = if ($res -is [System.Collections.IDictionary]) { $res['properties'] } else { $res.properties }
                # Flatten array properties to space-joined strings so Maester's
                # Compare-MtJsonObject does string comparison (shows actual values)
                # instead of ArraySizeMismatch (shows only counts).
                # Nested object arrays get JSON-serialized to preserve structure.
                $flatProps = @{}
                if ($resProps -is [System.Collections.IDictionary]) {
                    foreach ($pk in $resProps.Keys) {
                        $val = $resProps[$pk]
                        if ($val -is [Array] -and $val.Count -gt 0 -and ($val[0] -is [System.Collections.IDictionary] -or $val[0] -is [PSCustomObject])) {
                            $flatProps[$pk] = ($val | ConvertTo-Json -Depth 10 -Compress)
                        }
                        elseif ($val -is [Array]) { $flatProps[$pk] = $val -join ' ' }
                        else { $flatProps[$pk] = $val }
                    }
                }
                elseif ($resProps) {
                    foreach ($prop in $resProps.PSObject.Properties) {
                        $val = $prop.Value
                        if ($val -is [Array] -and $val.Count -gt 0 -and ($val[0] -is [System.Collections.IDictionary] -or $val[0] -is [PSCustomObject])) {
                            $flatProps[$prop.Name] = ($val | ConvertTo-Json -Depth 10 -Compress)
                        }
                        elseif ($val -is [Array]) { $flatProps[$prop.Name] = $val -join ' ' }
                        else { $flatProps[$prop.Name] = $val }
                    }
                }
                $key = "${resType}::${resDn}"
                $baselineData[$key] = @{
                    resourceType = $resType
                    displayName  = $resDn
                    properties   = $flatProps
                }
            }
        }

        # Build "current" by deep-copying baseline and applying drift deltas
        # NOTE: .Clone() is shallow — nested properties would be shared references.
        # Deep copy via JSON roundtrip to avoid mutating baselineData.
        $currentData = @{}
        foreach ($k in $baselineData.Keys) {
            $currentData[$k] = $baselineData[$k] | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
        }
        $monitorDrifts = @($drifts | Where-Object { $_.MonitorId -eq $monId })

        foreach ($drift in $monitorDrifts) {
            $key = "$($drift.ResourceType)::$($drift.ResourceDisplay)"

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

        $baselineData | ConvertTo-Json -Depth 20 | Set-Content -Path $baselineFile -Encoding utf8
        $currentData  | ConvertTo-Json -Depth 20 | Set-Content -Path $currentFile -Encoding utf8

        # Write settings.json for MT.1060 (optional metadata)
        $settingsFile = Join-Path $suitePath 'settings.json'
        @{
            Source    = 'EasyTCM'
            MonitorId = $monitor.id
            SyncedAt  = (Get-Date -Format 'o')
        } | ConvertTo-Json | Set-Content -Path $settingsFile -Encoding utf8

        # Write Pester .Tests.ps1 so Invoke-Maester discovers this suite directly
        $escapedName = $monDisplayName -replace "'", "''"
        $testContent = @"
# Auto-generated by EasyTCM Sync-TCMDriftToMaester — do not edit
Describe 'MT.1060: TCM Drift - $escapedName' -Tag 'TCM', 'Drift', 'MT.1060' {
    It 'MT.1060: $escapedName has no configuration drift' {
        `$suitePath = `$PSScriptRoot
        `$baseline = Get-Content (Join-Path `$suitePath 'baseline.json') -Raw | ConvertFrom-Json -AsHashtable
        `$current  = Get-Content (Join-Path `$suitePath 'current.json')  -Raw | ConvertFrom-Json -AsHashtable

        `$drifted = [System.Collections.Generic.List[string]]::new()
        foreach (`$key in @(@(`$baseline.Keys) + @(`$current.Keys) | Select-Object -Unique)) {
            if (-not `$baseline.ContainsKey(`$key)) { `$drifted.Add(('| ``[NEW]`` | ``{0}`` |' -f `$key)); continue }
            if (-not `$current.ContainsKey(`$key))  { `$drifted.Add(('| ``[DELETED]`` | ``{0}`` |' -f `$key)); continue }
            `$bJson = `$baseline[`$key] | ConvertTo-Json -Depth 20 -Compress
            `$cJson = `$current[`$key]  | ConvertTo-Json -Depth 20 -Compress
            if (`$bJson -ne `$cJson) { `$drifted.Add(('| ``[CHANGED]`` | ``{0}`` |' -f `$key)) }
        }

        `$desc = ("Compares the TCM monitor baseline with current tenant state for **$escapedName**.`n`nBaseline: ``{0}`` resources | Current: ``{1}`` resources" -f `$baseline.Count, `$current.Count)
        if (`$drifted.Count -eq 0) {
            Add-MtTestResultDetail -Description `$desc -Result "✅ All resources match the TCM baseline."
        } else {
            `$table = "| Status | Resource |`n|--------|----------|`n" + (`$drifted -join "`n")
            Add-MtTestResultDetail -Description `$desc -Result `$table
        }

        `$drifted | Should -HaveCount 0 -Because "all resources should match the TCM baseline"
    }
}
"@
        $testFile = Join-Path $suitePath 'TCM-Drift.Tests.ps1'
        Set-Content -Path $testFile -Value $testContent -Encoding utf8

        $summary = [PSCustomObject]@{
            MonitorName   = $monDisplayName
            MonitorId     = $monId
            SuitePath     = $suitePath
            BaselineFile  = $baselineFile
            CurrentFile   = $currentFile
            ResourceCount = $baselineData.Count
            DriftCount    = $monitorDrifts.Count
            DriftedProps  = ($monitorDrifts | ForEach-Object { $_.DriftedPropertyCount } | Measure-Object -Sum).Sum
        }
        $summaries.Add($summary)

        $driftIcon = if ($monitorDrifts.Count -gt 0) { '⚠️' } else { '✅' }
        Write-Host "  $driftIcon $monDisplayName`: $($monitorDrifts.Count) drifts across $($baselineData.Count) resources" -ForegroundColor $(if ($monitorDrifts.Count -gt 0) { 'Yellow' } else { 'Green' })
    }

    # Set the environment variable that MT.1060 uses for drift folder discovery.
    # NOTE: Maester v2.0.0 has a typo — reads MEASTER_FOLDER_DRIFT instead of MAESTER.
    # Set both so it works with current and future (fixed) versions.
    $resolvedOutput = (Resolve-Path $OutputPath).Path
    $env:MEASTER_FOLDER_DRIFT = $resolvedOutput
    $env:MAESTER_FOLDER_DRIFT = $resolvedOutput

    # Summary
    $totalDrifts = ($summaries | Measure-Object -Property DriftCount -Sum).Sum
    Write-Host ''
    if ($totalDrifts -gt 0) {
        Write-Host "⚠️  $totalDrifts active drifts synced across $($summaries.Count) monitors." -ForegroundColor Yellow
    }
    else {
        Write-Host "✅ No active drifts. All $($summaries.Count) monitors are clean." -ForegroundColor Green
    }
    Write-Host "   Drift folder: $resolvedOutput" -ForegroundColor DarkGray
    Write-Host "   Run: Invoke-Maester -Path $resolvedOutput" -ForegroundColor DarkGray
    if ($env:MAESTER_TESTS_PATH) {
        Write-Host "   Full suite: cd $($env:MAESTER_TESTS_PATH); Invoke-Maester" -ForegroundColor DarkGray
    }

    # Optional: run Compare-TCMBaseline and generate a baseline drift suite
    if ($CompareBaseline) {
        Write-Host ''
        Write-Host '🔗 Running baseline comparison (takes a snapshot)...' -ForegroundColor Cyan
        $compareParams = @{ Detailed = $true }
        if ($MonitorId) { $compareParams.MonitorId = $MonitorId }
        $comparison = Compare-TCMBaseline @compareParams

        if ($comparison -and ($comparison.NewCount -gt 0 -or $comparison.DeletedCount -gt 0)) {
            $blSuitePath = Join-Path $OutputPath 'TCM-BaselineDrift'
            if (-not (Test-Path $blSuitePath)) {
                New-Item -Path $blSuitePath -ItemType Directory -Force | Out-Null
            }

            # baseline.json = empty (no expected new/deleted resources)
            # current.json = new and deleted resources as entries
            $blBaseline = @{}
            $blCurrent = @{}

            foreach ($r in $comparison.NewResources) {
                $key = "NEW::$($r.ResourceType)::$($r.Id)"
                $blCurrent[$key] = @{
                    status       = 'New'
                    resourceType = $r.ResourceType
                    displayName  = $r.DisplayName
                    id           = $r.Id
                }
            }
            foreach ($r in $comparison.DeletedResources) {
                $key = "DELETED::$($r.ResourceType)::$($r.Id)"
                $blBaseline[$key] = @{
                    status       = 'Expected'
                    resourceType = $r.ResourceType
                    displayName  = $r.DisplayName
                    id           = $r.Id
                }
            }

            $blBaseline | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $blSuitePath 'baseline.json') -Encoding utf8
            $blCurrent  | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $blSuitePath 'current.json') -Encoding utf8
            @{
                Source    = 'EasyTCM-CompareBaseline'
                SyncedAt  = (Get-Date -Format 'o')
                NewCount  = $comparison.NewCount
                DeletedCount = $comparison.DeletedCount
            } | ConvertTo-Json | Set-Content -Path (Join-Path $blSuitePath 'settings.json') -Encoding utf8

            # Write Pester .Tests.ps1 for baseline drift
            $blTestContent = @"
# Auto-generated by EasyTCM Sync-TCMDriftToMaester — do not edit
Describe 'MT.1060: TCM Baseline Drift' -Tag 'TCM', 'BaselineDrift', 'MT.1060' {
    It 'MT.1060: No new or deleted resources detected' {
        `$suitePath = `$PSScriptRoot
        `$baseline = Get-Content (Join-Path `$suitePath 'baseline.json') -Raw | ConvertFrom-Json -AsHashtable
        `$current  = Get-Content (Join-Path `$suitePath 'current.json')  -Raw | ConvertFrom-Json -AsHashtable
        `$settings = Get-Content (Join-Path `$suitePath 'settings.json') -Raw | ConvertFrom-Json

        `$rows = [System.Collections.Generic.List[string]]::new()
        foreach (`$key in `$current.Keys) {
            `$r = `$current[`$key]
            `$type = if (`$r -is [System.Collections.IDictionary]) { `$r['resourceType'] } else { `$r.resourceType }
            `$name = if (`$r -is [System.Collections.IDictionary]) { `$r['displayName'] } else { `$r.displayName }
            `$id   = if (`$r -is [System.Collections.IDictionary]) { `$r['id'] } else { `$r.id }
            if (-not `$baseline.ContainsKey(`$key)) { `$rows.Add(('| ➕ New | ``{0}`` | {1} | ``{2}`` |' -f `$type, `$name, `$id)) }
        }
        foreach (`$key in `$baseline.Keys) {
            `$r = `$baseline[`$key]
            `$type = if (`$r -is [System.Collections.IDictionary]) { `$r['resourceType'] } else { `$r.resourceType }
            `$name = if (`$r -is [System.Collections.IDictionary]) { `$r['displayName'] } else { `$r.displayName }
            `$id   = if (`$r -is [System.Collections.IDictionary]) { `$r['id'] } else { `$r.id }
            if (-not `$current.ContainsKey(`$key)) { `$rows.Add(('| ❌ Deleted | ``{0}`` | {1} | ``{2}`` |' -f `$type, `$name, `$id)) }
        }

        `$desc = "Detects resources in the tenant that are **not tracked** by the TCM monitor baseline.`n`nNew resources may represent shadow configuration; deleted resources may indicate unauthorized removal."
        if (`$rows.Count -eq 0) {
            Add-MtTestResultDetail -Description `$desc -Result "✅ No untracked resources. Baseline is up to date."
        } else {
            `$table = "**`$(`$settings.NewCount) new, `$(`$settings.DeletedCount) deleted** resources detected:`n`n| Status | Type | Name | Id |`n|--------|------|------|----|`n" + (`$rows -join "`n")
            Add-MtTestResultDetail -Description `$desc -Result `$table
        }

        `$rows | Should -HaveCount 0 -Because "no untracked new or deleted resources should exist"
    }
}
"@
            Set-Content -Path (Join-Path $blSuitePath 'TCM-Drift.Tests.ps1') -Value $blTestContent -Encoding utf8

            Write-Host "  ⚠️  Baseline drift: $($comparison.NewCount) new, $($comparison.DeletedCount) deleted → $blSuitePath" -ForegroundColor Yellow
        }
        else {
            Write-Host '  ✅ No baseline drift (no new or deleted resources).' -ForegroundColor Green
        }
    }
    else {
        Write-Host ''
        Write-Host 'Tip: Use -CompareBaseline to also detect new/deleted resources (takes a snapshot).' -ForegroundColor DarkGray
    }

    if ($PassThru) { $summaries }
}
