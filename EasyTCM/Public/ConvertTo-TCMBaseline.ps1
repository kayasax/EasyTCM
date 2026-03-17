function ConvertTo-TCMBaseline {
    <#
    .SYNOPSIS
        Convert a TCM snapshot into a monitor baseline — the killer feature.
    .DESCRIPTION
        Takes a completed snapshot's content and transforms it into the baseline
        format expected by New-TCMMonitor. This is the bridge between "what is my
        current config" and "monitor it for drift".

        QUOTA REALITY: TCM allows 800 monitored resources/day across all monitors.
        Each monitor runs 4×/day (every 6h), so you can monitor ~200 resource
        instances total. Monitoring everything WILL blow your quota.

        Use -Profile to filter to what matters:
        - SecurityCritical  (~15 types) — CA policies, auth methods, mail security, federation
        - Recommended       (~30 types) — above + roles, compliance, device policies
        - Full              (all types) — everything from the snapshot (quota warning)

        Default is SecurityCritical — because monitoring 15 critical configs that
        actually alert you is better than monitoring 200 that blow your quota silently.

        Workflow:
        1. New-TCMSnapshot -Wait       → snapshot everything (cheap)
        2. ConvertTo-TCMBaseline       → filter to security-critical (smart)
        3. New-TCMMonitor              → monitor only what matters (quota-safe)
    .PARAMETER SnapshotContent
        The snapshot content object (from Get-TCMSnapshot -IncludeContent).
    .PARAMETER SnapshotId
        Alternatively, provide a snapshot job ID and the content will be fetched.
    .PARAMETER Profile
        Monitoring profile that filters resource types by security impact.
        - SecurityCritical: Identity + mail security + federation (~15 types, default)
        - Recommended: Above + roles, compliance, devices (~30 types)
        - Full: All resource types from the snapshot (watch your quota!)
    .PARAMETER DisplayName
        Name for the generated baseline. Defaults to "Baseline from snapshot".
    .PARAMETER Description
        Optional description for the baseline.
    .PARAMETER ExcludeResources
        Resource type names to exclude from the baseline (applied after profile filter).
    .EXAMPLE
        # Default: security-critical resources only (quota-safe)
        New-TCMSnapshot -DisplayName "Baseline" -Wait | ConvertTo-TCMBaseline

    .EXAMPLE
        # Broader coverage
        ConvertTo-TCMBaseline -SnapshotId $id -Profile Recommended

    .EXAMPLE
        # Everything (check your quota first with Get-TCMQuota)
        ConvertTo-TCMBaseline -SnapshotId $id -Profile Full
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ParameterSetName = 'Content')]
        [object]$SnapshotContent,

        [Parameter(ParameterSetName = 'Id')]
        [string]$SnapshotId,

        [ValidateSet('SecurityCritical', 'Recommended', 'Full')]
        [string]$Profile = 'SecurityCritical',

        [string]$DisplayName = 'Baseline from snapshot',

        [string]$Description,

        [string[]]$ExcludeResources
    )

    process {
        # Resolve content
        if ($SnapshotId) {
            $job = Get-TCMSnapshot -Id $SnapshotId -IncludeContent
            if ($job.status -ne 'succeeded' -and $job.status -ne 'partiallySuccessful') {
                throw "Snapshot '$SnapshotId' is not complete (status: $($job.status)). Wait for it to finish."
            }
            $SnapshotContent = $job.snapshotContent
        }

        if (-not $SnapshotContent) {
            throw 'No snapshot content provided. Use -SnapshotId or pipe a snapshot with content.'
        }

        # Resolve profile filter
        $profileFilter = $null
        if ($Profile -ne 'Full') {
            $profiles = Get-TCMMonitoringProfile
            $profileFilter = $profiles[$Profile]
            Write-Host "Profile '$Profile': filtering to $($profileFilter.Count) resource types" -ForegroundColor Cyan
        }
        else {
            Write-Warning "Profile 'Full' selected — includes ALL resource types. Check quota with Get-TCMQuota!"
        }

        # The snapshot content contains resource instances grouped by type.
        # We need to transform each into a baseline resource entry.
        $baselineResources = [System.Collections.Generic.List[object]]::new()

        # Handle both array and object formats
        $items = if ($SnapshotContent -is [System.Collections.IList]) {
            $SnapshotContent
        }
        elseif ($SnapshotContent.resources) {
            $SnapshotContent.resources
        }
        elseif ($SnapshotContent.value) {
            $SnapshotContent.value
        }
        else {
            Write-Warning 'Unexpected snapshot content format. Attempting direct conversion.'
            @($SnapshotContent)
        }

        $skippedTypes = @{}
        foreach ($item in $items) {
            $resourceType = $item.resourceType

            # Profile filter — skip types not in the selected profile
            if ($profileFilter -and $resourceType -notin $profileFilter) {
                $skippedTypes[$resourceType] = ($skippedTypes[$resourceType] ?? 0) + 1
                continue
            }

            if ($ExcludeResources -and $resourceType -in $ExcludeResources) {
                Write-Verbose "Excluding resource type: $resourceType"
                continue
            }

            # Build a baseline resource from the snapshot data
            # Truncate top-level displayName to 128 chars (API max)
            $topDisplayName = $item.displayName ?? "$resourceType instance"
            if ($topDisplayName.Length -gt 128) {
                $topDisplayName = $topDisplayName.Substring(0, 128)
            }

            $baselineResource = @{
                resourceType = $resourceType
                displayName  = $topDisplayName
                properties   = @{}
            }

            # Copy all configuration properties
            # Properties come as either hashtable (from Graph API) or PSCustomObject (from JSON)
            $props = if ($item.properties) { $item.properties } else { $item }

            $propEntries = if ($props -is [System.Collections.IDictionary]) {
                $props.GetEnumerator()
            }
            else {
                $props.PSObject.Properties | ForEach-Object { [PSCustomObject]@{ Key = $_.Name; Value = $_.Value } }
            }

            foreach ($entry in $propEntries) {
                $baselineResource.properties[$entry.Key] = $entry.Value
            }

            if ($baselineResource.properties.Count -gt 0) {
                $baselineResources.Add($baselineResource)
            }
        }

        Write-Host "Converted $($baselineResources.Count) resources into baseline." -ForegroundColor Cyan

        # Quota impact summary
        $dailyCost = $baselineResources.Count * 4
        $quotaPercent = [math]::Round(($dailyCost / 800) * 100, 1)
        $color = if ($quotaPercent -gt 80) { 'Red' } elseif ($quotaPercent -gt 50) { 'Yellow' } else { 'Green' }
        Write-Host "  Quota impact: $dailyCost / 800 resources per day ($quotaPercent%)" -ForegroundColor $color

        if ($skippedTypes.Count -gt 0) {
            $skippedTotal = ($skippedTypes.Values | Measure-Object -Sum).Sum
            Write-Host "  Filtered out: $skippedTotal instances across $($skippedTypes.Count) resource types (not in '$Profile' profile)" -ForegroundColor DarkGray
            Write-Verbose "Skipped types: $($skippedTypes.Keys -join ', ')"
        }

        if ($quotaPercent -gt 80) {
            Write-Warning "This baseline alone uses $quotaPercent% of daily quota. Consider using -Profile SecurityCritical or -ExcludeResources to reduce."
        }

        $baseline = @{
            displayName = $DisplayName
            resources   = $baselineResources
        }
        if ($Description) { $baseline.description = $Description }

        $baseline
    }
}
