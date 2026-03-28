function Edit-TCMMonitor {
    <#
    .SYNOPSIS
        Interactively edit what resource types your TCM monitor watches.
    .DESCRIPTION
        Opens an HTML page in the browser where you can select/deselect resource types
        using checkboxes and profile presets. Click "Copy PowerShell Command" to get the
        command that applies your changes, then paste it in your terminal.

        Use -ResourceTypes for non-interactive (scripted) updates. This takes a new
        snapshot of added types, merges into the baseline, and updates the monitor.

    .PARAMETER MonitorId
        Target monitor ID. Defaults to the first monitor found.
    .PARAMETER ResourceTypes
        Apply a specific set of resource types non-interactively. This:
        1. Compares current vs new selection
        2. Snapshots any newly added types
        3. Merges new resources into the existing baseline
        4. Removes resources of dropped types from the baseline
        5. Updates the monitor with the new baseline
    .PARAMETER DisplayName
        Optional new display name for the monitor.
    .EXAMPLE
        Edit-TCMMonitor
        # Opens interactive HTML editor in browser
    .EXAMPLE
        Edit-TCMMonitor -ResourceTypes @('microsoft.entra.conditionalaccesspolicy','microsoft.entra.authenticationmethodpolicy')
        # Non-interactive update to exactly these types
    .EXAMPLE
        Edit-TCMMonitor -MonitorId 'eca21d95-...' -ResourceTypes (Get-TCMResourceTypeCatalog).Keys
        # Monitor all 62 types (Full profile equivalent)
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Browser')]
    param(
        [string]$MonitorId,

        [Parameter(ParameterSetName = 'Apply', Mandatory)]
        [string[]]$ResourceTypes,

        [string]$DisplayName,

        [Parameter(ParameterSetName = 'Apply')]
        [switch]$Force
    )

    # ── Get monitor ───────────────────────────────────────────────
    $needsBaseline = ($PSCmdlet.ParameterSetName -eq 'Apply')
    $monitors = if ($needsBaseline -and $MonitorId) {
        # Apply mode: fetch single monitor with full baseline
        @(Get-TCMMonitor -Id $MonitorId -IncludeBaseline)
    } elseif ($needsBaseline) {
        # Apply mode without ID: get list, then re-fetch first with baseline
        $list = @(Get-TCMMonitor)
        if ($list.Count -gt 0) {
            @(Get-TCMMonitor -Id $list[0].Id -IncludeBaseline)
        } else { @() }
    } else {
        @(Get-TCMMonitor)
    }

    if ($monitors.Count -eq 0) {
        Write-Host ''
        Write-Host '  No monitors found. Create one first:' -ForegroundColor Yellow
        Write-Host '    Start-TCMMonitoring -Profile Recommended' -ForegroundColor Cyan
        Write-Host ''
        return
    }

    $monitor = if ($MonitorId) {
        $monitors | Where-Object { $_.Id -eq $MonitorId }
    } else {
        $monitors[0]
    }

    if (-not $monitor) {
        Write-Warning "Monitor '$MonitorId' not found. Use Get-TCMMonitor to list available monitors."
        return
    }

    $catalog = Get-TCMResourceTypeCatalog

    # ── Browser mode (interactive HTML editor) ────────────────────
    if ($PSCmdlet.ParameterSetName -eq 'Browser') {
        $html = Get-TCMMonitorHtml -Catalog $catalog -MonitorId $monitor.Id `
            -MonitorDisplayName $monitor.DisplayName -MonitorStatus $monitor.Status `
            -ResourceCount $monitor.ResourceCount -MonitoredTypes @($monitor.MonitoredTypes) -Mode Edit

        $tempPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "EasyTCM-Edit-$(Get-Date -Format 'yyyyMMdd-HHmmss').html")
        $html | Set-Content -Path $tempPath -Encoding utf8
        Start-Process $tempPath

        Write-Host ''
        Write-Host '  Opened interactive editor in browser.' -ForegroundColor Green
        Write-Host '  Select resource types, then click "Copy PowerShell Command" and paste here.' -ForegroundColor Gray
        Write-Host ''
        return
    }

    # ── Apply mode (non-interactive) ──────────────────────────────
    $newTypes = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@($ResourceTypes),
        [StringComparer]::OrdinalIgnoreCase
    )

    # Validate resource types against catalog
    $invalidTypes = @($ResourceTypes | Where-Object { -not $catalog.ContainsKey($_) })
    if ($invalidTypes.Count -gt 0) {
        Write-Warning "Unknown resource types (not in catalog): $($invalidTypes -join ', ')"
        Write-Warning 'Use (Get-TCMResourceTypeCatalog).Keys to see valid types.'
        return
    }

    # Expand current types to detected profile (same logic as HTML page).
    # A Recommended monitor covers all Recommended types even if some have
    # zero baseline resources — the HTML page checks them all.
    $currentTypes = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@($monitor.MonitoredTypes),
        [StringComparer]::OrdinalIgnoreCase
    )
    $profiles = Get-TCMMonitoringProfile
    $scSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@($profiles.SecurityCritical), [StringComparer]::OrdinalIgnoreCase)
    $recSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@($profiles.Recommended), [StringComparer]::OrdinalIgnoreCase)
    if ($currentTypes.IsSubsetOf($scSet)) {
        foreach ($pt in $profiles.SecurityCritical) { [void]$currentTypes.Add($pt) }
    } elseif ($currentTypes.IsSubsetOf($recSet)) {
        foreach ($pt in $profiles.Recommended) { [void]$currentTypes.Add($pt) }
    }

    # Compute diff against expanded profile set
    $added = @($ResourceTypes | Where-Object { -not $currentTypes.Contains($_) })
    $removed = @($currentTypes | Where-Object { -not $newTypes.Contains($_) })

    if ($added.Count -eq 0 -and $removed.Count -eq 0 -and -not $DisplayName) {
        Write-Host '  No changes detected. Monitor already matches the requested configuration.' -ForegroundColor Green
        return
    }

    # Summary
    Write-Host ''
    Write-Host "  Monitor: $($monitor.DisplayName) ($($monitor.Id))" -ForegroundColor Cyan
    Write-Host "  Current: $($currentTypes.Count) types → New: $($newTypes.Count) types" -ForegroundColor Gray
    if ($added.Count -gt 0) {
        Write-Host "  + Adding $($added.Count) types:" -ForegroundColor Green
        foreach ($t in $added) {
            $dn = if ($catalog.ContainsKey($t)) { $catalog[$t].DisplayName } else { $t }
            Write-Host "      $dn" -ForegroundColor Green
        }
    }
    if ($removed.Count -gt 0) {
        Write-Host "  - Removing $($removed.Count) types:" -ForegroundColor Red
        foreach ($t in $removed) {
            $dn = if ($catalog.ContainsKey($t)) { $catalog[$t].DisplayName } else { $t }
            Write-Host "      $dn" -ForegroundColor Red
        }
    }
    if ($added.Count -gt 0) {
        # Quota pre-flight check
        $quota = Get-TCMQuota -PassThru 6>$null
        $dailyUsed = if ($quota) { $quota.DailyResourceUsage } else { 0 }
        $dailyLimit = 800
        $snapUsed = if ($quota) { $quota.SnapshotJobCount } else { 0 }
        $snapLimit = 12

        Write-Host ''
        Write-Host '  ⚠️  Snapshot required for new types:' -ForegroundColor Yellow
        Write-Host "     Daily resources: $dailyUsed / $dailyLimit used ($([math]::Round($dailyUsed / $dailyLimit * 100))%)" -ForegroundColor Gray
        Write-Host "     Snapshot jobs:   $snapUsed / $snapLimit used" -ForegroundColor Gray

        if ($snapUsed -ge $snapLimit) {
            Write-Warning "Snapshot job limit reached ($snapUsed/$snapLimit). Cannot create snapshot for new types."
            Write-Warning 'Wait for existing snapshot jobs to complete or expire, then retry.'
            return
        }
        if ($dailyUsed -ge $dailyLimit) {
            Write-Warning "Daily resource quota exhausted ($dailyUsed/$dailyLimit). Snapshot will likely fail."
            Write-Warning 'Wait until tomorrow (UTC midnight reset) or reduce the number of new types.'
            return
        }
    }
    Write-Host ''

    # ── Drift warning (single confirmation point) ───────────────
    # -WhatIf: show what would happen and stop
    if (-not $PSCmdlet.ShouldProcess("Monitor '$($monitor.DisplayName)'", "Update baseline ($($added.Count) added, $($removed.Count) removed)")) {
        return
    }
    # -Force: skip interactive confirmation
    if (-not $Force) {
        $driftMsg = "This will update the baseline for '$($monitor.DisplayName)'.`n" +
                   "  - Existing drift records will be reset (re-baselined).`n" +
                   "  - Types added: $($added.Count), removed: $($removed.Count).`n" +
                   'Continue?'
        if (-not $PSCmdlet.ShouldContinue($driftMsg, 'Confirm baseline update')) {
            return
        }
    }

    # ── Step 1: Snapshot added types if any ───────────────────────
    $newResources = @()
    if ($added.Count -gt 0) {
        Write-Host '  Snapshotting newly added types...' -ForegroundColor Gray
        $snapshotName = "EasyTCM Edit $(Get-Date -Format 'yyyyMMdd HHmmss')"
        $snapshot = New-TCMSnapshot -DisplayName $snapshotName -Resources $added -Wait

        if (-not $snapshot) {
            Write-Warning 'Snapshot creation failed. Cannot add new types.'
            Write-Warning 'Monitor was NOT modified — no changes applied.'
            return
        }

        $snapshotStatus = if ($snapshot -is [System.Collections.IDictionary]) { $snapshot['status'] } else { $snapshot.status }
        $snapshotId = if ($snapshot -is [System.Collections.IDictionary]) { $snapshot['id'] } else { $snapshot.id }

        if ($snapshotStatus -notin @('succeeded', 'partiallySuccessful')) {
            $errDetail = if ($snapshot.errorDetails) { $snapshot.errorDetails -join '; ' } else { $snapshotStatus }
            Write-Warning "Snapshot failed ($errDetail). Cannot add new types."
            if ($snapshotStatus -eq 'quotaExceeded' -or $errDetail -match 'quota') {
                Write-Warning 'Daily resource quota exceeded. Wait until UTC midnight reset or reduce the number of new types.'
            }
            Write-Warning 'Monitor was NOT modified — no changes applied.'
            return
        }

        # Convert snapshot content to baseline resources
        $snapshotJob = Get-TCMSnapshot -Id $snapshotId -IncludeContent
        $snapContent = if ($snapshotJob -is [System.Collections.IDictionary]) { $snapshotJob['snapshotContent'] } else { $snapshotJob.snapshotContent }
        if (-not $snapContent) {
            Write-Warning 'Snapshot succeeded but content could not be retrieved.'
            Write-Warning 'Monitor was NOT modified — no changes applied.'
            return
        }
        $origWarnPref = $WarningPreference
        try {
            $WarningPreference = 'SilentlyContinue'
            $newBaselineTemp = ConvertTo-TCMBaseline -SnapshotContent $snapContent -Profile Full -DisplayName 'temp' 6>$null
        }
        finally { $WarningPreference = $origWarnPref }

        if ($newBaselineTemp -and $newBaselineTemp.Resources) {
            $newResources = @($newBaselineTemp.Resources)
        }

        # Clean up snapshot
        if ($snapshotId) {
            Remove-TCMSnapshot -Id $snapshotId -Confirm:$false -ErrorAction SilentlyContinue
        }

        if ($newResources.Count -eq 0) {
            Write-Warning "Snapshot succeeded but returned 0 resources for the $($added.Count) new types."
            Write-Warning 'This may mean those resource types have no instances in your tenant.'
            Write-Warning 'Monitor was NOT modified — no changes applied.'
            return
        }

        Write-Host "  Captured $($newResources.Count) resources from $($added.Count) new types." -ForegroundColor Gray
    }

    # ── Step 2: Build updated baseline ────────────────────────────
    Write-Host '  Building updated baseline...' -ForegroundColor Gray

    # Get current baseline resources
    $currentBaseline = $monitor.Baseline
    $existingResources = @()
    if ($currentBaseline) {
        $bRes = if ($currentBaseline -is [System.Collections.IDictionary]) { $currentBaseline['resources'] } else { $currentBaseline.resources }
        if ($bRes) { $existingResources = @($bRes) }
    }

    # Filter out removed types from existing resources
    $keptResources = @($existingResources | Where-Object {
        $rt = if ($_ -is [System.Collections.IDictionary]) { $_['resourceType'] } else { $_.resourceType }
        $newTypes.Contains($rt)
    })

    # Merge kept + new resources
    $allResources = @($keptResources) + @($newResources)

    if ($allResources.Count -eq 0) {
        Write-Warning 'Resulting baseline would have 0 resources — the API requires at least one.'
        Write-Warning 'Monitor was NOT modified — no changes applied.'
        return
    }

    $currentName = if ($currentBaseline -is [System.Collections.IDictionary]) { $currentBaseline['displayName'] } else { $currentBaseline.displayName }
    $baselineName = if ($DisplayName) { $DisplayName } else { $currentName ?? $monitor.DisplayName }

    $newBaseline = @{
        DisplayName = $baselineName
        Resources   = $allResources
    }

    # ── Step 3: Update monitor ────────────────────────────────────
    Write-Host '  Updating monitor...' -ForegroundColor Gray

    $updateParams = @{ Id = $monitor.Id; Baseline = $newBaseline; Confirm = $false }
    if ($DisplayName) { $updateParams.DisplayName = $DisplayName }

    try {
        Update-TCMMonitor @updateParams -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to update monitor: $_"
        Write-Warning 'Monitor may not have been modified. Check with Get-TCMMonitor.'
        return
    }

    $quotaEst = $allResources.Count * 4
    Write-Host ''
    Write-Host "  ✅ Monitor updated: $($allResources.Count) resources across $($newTypes.Count) types" -ForegroundColor Green
    Write-Host "  Quota: ~$quotaEst / 800 resources per day ($([math]::Round($quotaEst / 800 * 100))%)" -ForegroundColor Gray

    if ($removed.Count -gt 0) {
        Write-Host '  ⚠️  Drift records for removed types will be cleared on next run.' -ForegroundColor Yellow
    }

    Write-Host ''
}
