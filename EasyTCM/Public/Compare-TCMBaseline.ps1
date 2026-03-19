function Compare-TCMBaseline {
    <#
    .SYNOPSIS
        Detect new or deleted resources not tracked by TCM drift monitoring.
    .DESCRIPTION
        TCM monitors only detect property changes on resources that exist in the
        baseline. New resources added to the tenant (e.g., a rogue CA policy) or
        deleted resources are invisible to drift detection.

        This cmdlet fills that gap by comparing the monitor's baseline against a
        fresh snapshot to find:
        - New resources: present in the tenant but not in the baseline
        - Deleted resources: in the baseline but no longer in the tenant
        - Matched resources: covered by TCM drift detection (shown with -Detailed)

        The snapshot covers all resource types from the monitoring profile
        (default: Recommended), not just types with existing data in the baseline.
        This ensures new resources in previously-empty types are detected.
    .PARAMETER MonitorId
        The monitor to compare. If omitted, uses the first active monitor.
    .PARAMETER Profile
        Monitoring profile that defines which resource types to snapshot.
        Default: Recommended. This should match the profile used to create the baseline.
    .PARAMETER Detailed
        Show per-resource instance details, not just summary counts.
    .PARAMETER KeepSnapshot
        Don't auto-delete the comparison snapshot job after analysis.
    .PARAMETER Force
        Bypass the 1-hour result cache and take a fresh snapshot.
    .PARAMETER WhatIf
        Preview which resource types will be snapshotted and the quota cost.
    .EXAMPLE
        Compare-TCMBaseline
    .EXAMPLE
        Compare-TCMBaseline -Detailed
    .EXAMPLE
        Compare-TCMBaseline -MonitorId 'eca21d95-...' -KeepSnapshot
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$MonitorId,

        [ValidateSet('SecurityCritical', 'Recommended', 'Full')]
        [string]$Profile = 'Recommended',

        [switch]$Detailed,
        [switch]$KeepSnapshot,
        [switch]$Force
    )

    # Check cache (1-hour TTL) — avoids re-snapshotting for repeated calls
    if (-not $Force -and $script:CompareBaselineCache -and
        $script:CompareBaselineCache.CachedAt -gt (Get-Date).AddHours(-1)) {
        $cached = $script:CompareBaselineCache.Result
        Write-Host "Using cached baseline comparison from $($script:CompareBaselineCache.CachedAt.ToString('HH:mm:ss')) ($($cached.NewCount) new, $($cached.DeletedCount) deleted). Use -Force to refresh." -ForegroundColor DarkGray
        return $cached
    }

    # 1. Resolve monitor and get baseline
    Write-Host 'Retrieving monitor baseline...' -ForegroundColor Cyan
    $monitor = if ($MonitorId) {
        Get-TCMMonitor -Id $MonitorId -IncludeBaseline
    }
    else {
        $all = Get-TCMMonitor -IncludeBaseline
        if ($all -is [array]) { $all[0] } else { $all }
    }

    if (-not $monitor) {
        throw 'No monitor found. Create one first with New-TCMMonitor.'
    }

    $monitorName = $monitor.DisplayName
    $baselineObj = $monitor.Baseline
    if (-not $baselineObj) {
        throw "Could not retrieve baseline for monitor '$monitorName'."
    }

    $baselineResources = if ($baselineObj.resources) { @($baselineObj.resources) }
                         elseif ($baselineObj.Resources) { @($baselineObj.Resources) }
                         else { @() }

    if ($baselineResources.Count -eq 0) {
        throw "Monitor '$monitorName' has an empty baseline."
    }

    # 2. Extract distinct resource types from baseline AND profile
    $baselineTypes = @($baselineResources | ForEach-Object {
        if ($_ -is [System.Collections.IDictionary]) { $_['ResourceType'] ?? $_['resourceType'] }
        else { $_.ResourceType ?? $_.resourceType }
    } | Select-Object -Unique)

    # Include all types from the monitoring profile — not just baseline types
    # This catches new resources in types that had zero instances at baseline time
    $profiles = Get-TCMMonitoringProfile
    $profileTypes = if ($Profile -eq 'Full') {
        # For Full, use all known types from all workloads
        $workloads = Get-TCMWorkloadResources
        $workloads.Values | ForEach-Object { $_ } | Select-Object -Unique
    } else {
        $profiles[$Profile]
    }
    $snapshotTypes = @(@($baselineTypes) + @($profileTypes) | Select-Object -Unique | Sort-Object)

    Write-Host "  Monitor: $monitorName ($($baselineResources.Count) resources across $($baselineTypes.Count) types)" -ForegroundColor DarkGray
    Write-Host "  Profile: $Profile ($($snapshotTypes.Count) types to scan)" -ForegroundColor DarkGray

    # 3. WhatIf: show preview
    if (-not $PSCmdlet.ShouldProcess("Snapshot $($snapshotTypes.Count) resource types ($Profile profile)", 'Create comparison snapshot')) {
        Write-Host "`nPreview — resource types that would be snapshotted:" -ForegroundColor Yellow
        foreach ($t in $snapshotTypes | Sort-Object) {
            $count = @($baselineResources | Where-Object {
                $rt = if ($_ -is [System.Collections.IDictionary]) { $_['ResourceType'] ?? $_['resourceType'] } else { $_.ResourceType ?? $_.resourceType }
                $rt -eq $t
            }).Count
            $marker = if ($count -eq 0) { ' (no baseline data)' } else { " ($count in baseline)" }
            Write-Host "  $t$marker"
        }
        Write-Host "`nEstimated snapshot quota cost against 20,000/month limit" -ForegroundColor Yellow
        return
    }

    # 4. Take a fresh snapshot of all profile resource types
    Write-Host 'Taking comparison snapshot...' -ForegroundColor Cyan
    $snapshotName = "Compare $(Get-Date -Format 'yyyyMMdd HHmmss')"
    $snapshotJob = New-TCMSnapshot -DisplayName $snapshotName -Resources $snapshotTypes -Wait -TimeoutSeconds 300

    $jobId = if ($snapshotJob -is [System.Collections.IDictionary]) { $snapshotJob['id'] } else { $snapshotJob.id }
    $jobStatus = if ($snapshotJob -is [System.Collections.IDictionary]) { $snapshotJob['status'] } else { $snapshotJob.status }

    if ($jobStatus -notin @('succeeded', 'partiallySuccessful')) {
        Write-Warning "Snapshot status: $jobStatus — comparison may be incomplete."
    }

    # 5. Fetch snapshot content
    Write-Host 'Fetching snapshot content...' -ForegroundColor Cyan
    $snapshot = Get-TCMSnapshot -Id $jobId -IncludeContent
    $snapshotContent = if ($snapshot -is [System.Collections.IDictionary]) { $snapshot['snapshotContent'] } else { $snapshot.snapshotContent }

    $snapshotResources = @()
    if ($snapshotContent) {
        $snapshotResources = if ($snapshotContent.resources) { @($snapshotContent.resources) }
                             elseif ($snapshotContent.Resources) { @($snapshotContent.Resources) }
                             elseif ($snapshotContent -is [System.Collections.IList]) { @($snapshotContent) }
                             else { @() }
    }

    Write-Host "  Snapshot: $($snapshotResources.Count) resources returned" -ForegroundColor DarkGray

    # 6. Build lookup tables keyed by resourceType + unique identifier
    #    Fallback chain: Properties.Id → Identity → Name → top-level displayName
    #    Some types (transportrule, dlpcompliancepolicy) lack Id/Identity but have Name.
    $baselineLookup = @{}
    foreach ($r in $baselineResources) {
        $rt = if ($r -is [System.Collections.IDictionary]) { $r['ResourceType'] ?? $r['resourceType'] } else { $r.ResourceType ?? $r.resourceType }
        $props = if ($r -is [System.Collections.IDictionary]) { $r['Properties'] ?? $r['properties'] } else { $r.Properties ?? $r.properties }
        $id = if ($props -is [System.Collections.IDictionary]) {
            $props['Id'] ?? $props['id'] ?? $props['Identity'] ?? $props['identity'] ?? $props['Name'] ?? $props['name']
        } else {
            $props.Id ?? $props.id ?? $props.Identity ?? $props.identity ?? $props.Name ?? $props.name
        }
        if (-not $id) {
            $id = if ($r -is [System.Collections.IDictionary]) { $r['DisplayName'] ?? $r['displayName'] } else { $r.DisplayName ?? $r.displayName }
            if ($id -and $id.Length -gt 128) { $id = $id.Substring(0, 128) }
        }
        $dn = if ($props -is [System.Collections.IDictionary]) { $props['DisplayName'] ?? $props['displayName'] ?? $props['Name'] ?? $props['name'] }
              else { $props.DisplayName ?? $props.displayName ?? $props.Name ?? $props.name }

        $key = "$rt|$id"
        $baselineLookup[$key] = @{ ResourceType = $rt; Id = $id; DisplayName = $dn; Source = 'Baseline' }
    }

    $snapshotLookup = @{}
    foreach ($r in $snapshotResources) {
        $rt = if ($r -is [System.Collections.IDictionary]) { $r['resourceType'] ?? $r['ResourceType'] } else { $r.resourceType ?? $r.ResourceType }
        $props = if ($r -is [System.Collections.IDictionary]) { $r['properties'] ?? $r['Properties'] } else { $r.properties ?? $r.Properties }
        $id = if ($props -is [System.Collections.IDictionary]) {
            $props['Id'] ?? $props['id'] ?? $props['Identity'] ?? $props['identity'] ?? $props['Name'] ?? $props['name']
        } else {
            $props.Id ?? $props.id ?? $props.Identity ?? $props.identity ?? $props.Name ?? $props.name
        }
        if (-not $id) {
            $id = if ($r -is [System.Collections.IDictionary]) { $r['displayName'] ?? $r['DisplayName'] } else { $r.displayName ?? $r.DisplayName }
            if ($id -and $id.Length -gt 128) { $id = $id.Substring(0, 128) }
        }
        $dn = if ($props -is [System.Collections.IDictionary]) { $props['DisplayName'] ?? $props['displayName'] ?? $props['Name'] ?? $props['name'] }
              else { $props.DisplayName ?? $props.displayName ?? $props.Name ?? $props.name }

        $key = "$rt|$id"
        $snapshotLookup[$key] = @{ ResourceType = $rt; Id = $id; DisplayName = $dn; Source = 'Snapshot' }
    }

    # 7. Compare: find new, deleted, matched
    $newResources = [System.Collections.Generic.List[object]]::new()
    $deletedResources = [System.Collections.Generic.List[object]]::new()
    $matchedCount = 0

    foreach ($key in $snapshotLookup.Keys) {
        if (-not $baselineLookup.ContainsKey($key)) {
            $newResources.Add($snapshotLookup[$key])
        }
        else {
            $matchedCount++
        }
    }

    foreach ($key in $baselineLookup.Keys) {
        if (-not $snapshotLookup.ContainsKey($key)) {
            $deletedResources.Add($baselineLookup[$key])
        }
    }

    # 8. Build per-type summary
    $allTypes = @($baselineTypes + @($snapshotResources | ForEach-Object {
        if ($_ -is [System.Collections.IDictionary]) { $_['resourceType'] ?? $_['ResourceType'] } else { $_.resourceType ?? $_.ResourceType }
    })) | Select-Object -Unique | Sort-Object

    $results = foreach ($t in $allTypes) {
        $bCount = @($baselineResources | Where-Object {
            $rt = if ($_ -is [System.Collections.IDictionary]) { $_['ResourceType'] ?? $_['resourceType'] } else { $_.ResourceType ?? $_.resourceType }
            $rt -eq $t
        }).Count

        $sCount = @($snapshotResources | Where-Object {
            $rt = if ($_ -is [System.Collections.IDictionary]) { $_['resourceType'] ?? $_['ResourceType'] } else { $_.resourceType ?? $_.ResourceType }
            $rt -eq $t
        }).Count

        $newCount = @($newResources | Where-Object { $_.ResourceType -eq $t }).Count
        $delCount = @($deletedResources | Where-Object { $_.ResourceType -eq $t }).Count

        $status = if ($newCount -gt 0 -and $delCount -gt 0) { "+$newCount New / -$delCount Deleted" }
                  elseif ($newCount -gt 0) { "+$newCount New" }
                  elseif ($delCount -gt 0) { "-$delCount Deleted" }
                  else { 'OK' }

        # Extract short type name for display
        $shortType = ($t -split '\.')[-1]

        [PSCustomObject]@{
            PSTypeName    = 'EasyTCM.BaselineComparison'
            ResourceType  = $t
            ShortType     = $shortType
            Baseline      = $bCount
            Current       = $sCount
            New           = $newCount
            Deleted       = $delCount
            Status        = $status
        }
    }

    # 9. Display results
    $hasChanges = ($newResources.Count -gt 0 -or $deletedResources.Count -gt 0)
    Write-Host ''
    if ($hasChanges) {
        Write-Host "  BASELINE DRIFT DETECTED" -ForegroundColor Red
        Write-Host "  $($newResources.Count) new resource(s), $($deletedResources.Count) deleted resource(s), $matchedCount matched" -ForegroundColor Yellow
    }
    else {
        Write-Host "  NO BASELINE DRIFT" -ForegroundColor Green
        Write-Host "  All $matchedCount resources in baseline match the current tenant" -ForegroundColor DarkGray
    }
    Write-Host ''

    # Summary table
    $results | Format-Table ResourceType, Baseline, Current, New, Deleted, Status -AutoSize | Out-String | Write-Host

    # Detailed view
    if ($Detailed -and $hasChanges) {
        if ($newResources.Count -gt 0) {
            Write-Host '  NEW RESOURCES (not in baseline):' -ForegroundColor Yellow
            foreach ($r in $newResources | Sort-Object { $_.ResourceType }) {
                $shortType = ($r.ResourceType -split '\.')[-1]
                Write-Host "    [+] $shortType — $($r.DisplayName) (Id: $($r.Id))" -ForegroundColor Green
            }
            Write-Host ''
        }

        if ($deletedResources.Count -gt 0) {
            Write-Host '  DELETED RESOURCES (in baseline but gone):' -ForegroundColor Yellow
            foreach ($r in $deletedResources | Sort-Object { $_.ResourceType }) {
                $shortType = ($r.ResourceType -split '\.')[-1]
                Write-Host "    [-] $shortType — $($r.DisplayName) (Id: $($r.Id))" -ForegroundColor Red
            }
            Write-Host ''
        }
    }

    # 10. Cleanup snapshot
    if (-not $KeepSnapshot -and $jobId) {
        Write-Host 'Cleaning up comparison snapshot...' -ForegroundColor DarkGray
        try {
            Remove-TCMSnapshot -Id $jobId -Confirm:$false
        }
        catch {
            Write-Debug "Could not auto-delete snapshot $jobId : $_"
        }
    }

    # Return structured output
    $result = [PSCustomObject]@{
        PSTypeName       = 'EasyTCM.BaselineComparisonResult'
        Monitor          = $monitorName
        MonitorId        = $monitor.Id
        BaselineCount    = $baselineResources.Count
        CurrentCount     = $snapshotResources.Count
        NewCount         = $newResources.Count
        DeletedCount     = $deletedResources.Count
        MatchedCount     = $matchedCount
        HasDrift         = $hasChanges
        NewResources     = $newResources
        DeletedResources = $deletedResources
        TypeSummary      = $results
        SnapshotId       = if ($KeepSnapshot) { $jobId } else { $null }
    }

    # Cache result for 1 hour
    $script:CompareBaselineCache = @{ Result = $result; CachedAt = Get-Date }

    $result
}
