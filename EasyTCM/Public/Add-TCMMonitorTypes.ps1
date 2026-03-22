function Add-TCMMonitorTypes {
    <#
    .SYNOPSIS
        Add resource types from a template to an existing monitor without losing drift.
    .DESCRIPTION
        When you want to expand monitoring coverage (e.g., add CISA SCuBA types to an
        existing SecurityCritical monitor), this cmdlet:

        1. Reads the current monitor baseline
        2. Determines which new resource types are needed
        3. Takes a targeted snapshot of ONLY those new types
        4. Merges the new resources into the existing baseline
        5. Updates the monitor with the merged baseline

        IMPORTANT: Updating a monitor baseline DOES delete existing drift records.
        However, this cmdlet minimizes impact — your existing baseline values stay
        identical, so TCM will immediately re-detect the same drifts on the next
        monitoring cycle (within 6 hours). Only the drift *history* is lost, not the
        detection ability.

    .PARAMETER MonitorId
        The monitor to expand. If omitted, uses the first active monitor.
    .PARAMETER MonitorName
        Resolve monitor by display name instead of ID.
    .PARAMETER Template
        Name(s) of built-in templates (from templates/ folder).
        Available: EasyTCM-SecurityCritical, EasyTCM-Recommended,
        CISA-SCuBA-Entra, CISA-SCuBA-Exchange, CISA-SCuBA-Teams
    .PARAMETER TemplatePath
        Path(s) to custom template JSON files.
    .PARAMETER Force
        Skip the confirmation prompt.

    .EXAMPLE
        # Add CISA Exchange + Teams types to existing monitor
        Add-TCMMonitorTypes -Template CISA-SCuBA-Exchange, CISA-SCuBA-Teams

    .EXAMPLE
        # Expand to full Recommended profile
        Add-TCMMonitorTypes -Template EasyTCM-Recommended

    .EXAMPLE
        # Non-interactive
        Add-TCMMonitorTypes -Template CISA-SCuBA-Entra -Force
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [string]$MonitorId,

        [string]$MonitorName,

        [string[]]$Template,

        [string[]]$TemplatePath,

        [switch]$Force
    )

    if (-not $Template -and -not $TemplatePath) {
        throw 'Specify at least one -Template or -TemplatePath.'
    }

    Write-Host ''
    Write-Host '➕ Add-TCMMonitorTypes — Expand monitor coverage without rebaselining' -ForegroundColor Cyan
    Write-Host ''

    # ── Resolve monitor ─────────────────────────────────────────────
    Write-Host 'Retrieving current monitor...' -ForegroundColor White
    $monitor = if ($MonitorId) {
        Get-TCMMonitor -Id $MonitorId -IncludeBaseline
    }
    elseif ($MonitorName) {
        $all = Get-TCMMonitor
        $match = @($all) | Where-Object {
            $dn = if ($_ -is [System.Collections.IDictionary]) { $_['displayName'] } else { $_.displayName }
            $dn -eq $MonitorName
        }
        if (-not $match) {
            Write-Error "No monitor found with name '$MonitorName'."
            return
        }
        $matchId = if ($match -is [System.Collections.IDictionary]) { $match['id'] } else { $match.id }
        Get-TCMMonitor -Id $matchId -IncludeBaseline
    }
    else {
        $all = Get-TCMMonitor
        if (-not $all) {
            Write-Error 'No monitor found. Create one first with Start-TCMMonitoring.'
            return
        }
        $first = if ($all -is [array]) { $all[0] } else { $all }
        $firstId = if ($first -is [System.Collections.IDictionary]) { $first['id'] } else { $first.id }
        Get-TCMMonitor -Id $firstId -IncludeBaseline
    }

    if (-not $monitor) {
        Write-Error 'Monitor not found.'
        return
    }

    $mId = if ($monitor -is [System.Collections.IDictionary]) { $monitor['id'] } else { $monitor.id }
    $mName = if ($monitor -is [System.Collections.IDictionary]) { $monitor['displayName'] } else { $monitor.displayName }
    $existingBaseline = if ($monitor -is [System.Collections.IDictionary]) { $monitor['Baseline'] } else { $monitor.Baseline }

    # Get existing resource types
    $existingResources = @()
    if ($existingBaseline) {
        $bResources = if ($existingBaseline -is [System.Collections.IDictionary]) { $existingBaseline['resources'] } else { $existingBaseline.resources }
        if ($bResources) { $existingResources = @($bResources) }
    }

    $existingTypes = @($existingResources | ForEach-Object {
        if ($_ -is [System.Collections.IDictionary]) { $_['resourceType'] } else { $_.resourceType }
    } | Sort-Object -Unique)

    Write-Host "  Monitor: $mName" -ForegroundColor DarkGray
    Write-Host "  Current: $($existingResources.Count) resources across $($existingTypes.Count) types" -ForegroundColor DarkGray

    # ── Resolve template types ──────────────────────────────────────
    $templateTypes = [System.Collections.Generic.List[string]]::new()
    $templateNames = [System.Collections.Generic.List[string]]::new()
    $templatesDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'templates'

    foreach ($name in @($Template)) {
        if (-not $name) { continue }
        $fileName = $name.ToLower() + '.json'
        $path = Join-Path $templatesDir $fileName
        if (-not (Test-Path $path)) {
            throw "Template '$name' not found at: $path"
        }
        $tmpl = Get-Content $path -Raw | ConvertFrom-Json
        $templateNames.Add($tmpl.metadata.displayName)
        foreach ($rt in $tmpl.resourceTypes) { if ($rt -notin $templateTypes) { $templateTypes.Add($rt) } }
    }

    foreach ($path in @($TemplatePath)) {
        if (-not $path) { continue }
        if (-not (Test-Path $path)) {
            throw "Template file not found: $path"
        }
        $tmpl = Get-Content $path -Raw | ConvertFrom-Json
        $templateNames.Add($tmpl.metadata.displayName)
        foreach ($rt in $tmpl.resourceTypes) { if ($rt -notin $templateTypes) { $templateTypes.Add($rt) } }
    }

    # ── Determine new types ─────────────────────────────────────────
    $newTypes = @($templateTypes | Where-Object { $_ -notin $existingTypes })

    Write-Host ''
    Write-Host "  Template(s): $($templateNames -join ' + ')" -ForegroundColor Cyan
    Write-Host "  Template types: $($templateTypes.Count) total" -ForegroundColor DarkGray
    Write-Host "  Already monitored: $($templateTypes.Count - $newTypes.Count)" -ForegroundColor DarkGray
    Write-Host "  New types to add: $($newTypes.Count)" -ForegroundColor $(if ($newTypes.Count -gt 0) { 'Yellow' } else { 'Green' })

    if ($newTypes.Count -eq 0) {
        Write-Host ''
        Write-Host '✅ Monitor already covers all resource types in the specified template(s).' -ForegroundColor Green
        Write-Host ''
        return
    }

    foreach ($nt in $newTypes) {
        $shortName = ($nt -split '\.')[-1]
        Write-Host "    + $shortName ($nt)" -ForegroundColor Yellow
    }

    # Quota impact
    $newDailyCost = ($existingResources.Count + $newTypes.Count) * 4  # Rough estimate (1 instance per new type minimum)
    Write-Host ''
    Write-Host "  ⚠  Updating the baseline will clear existing drift records." -ForegroundColor Yellow
    Write-Host "     Existing drifts will be re-detected within 6 hours (baseline values preserved)." -ForegroundColor DarkGray

    # ── Confirmation ────────────────────────────────────────────────
    if (-not $Force) {
        if (-not $PSCmdlet.ShouldProcess("Monitor '$mName'", "Add $($newTypes.Count) resource types (clears drift history)")) {
            return
        }
    }

    # ── Snapshot only the new types ─────────────────────────────────
    Write-Host ''
    Write-Host "Taking targeted snapshot of $($newTypes.Count) new resource types..." -ForegroundColor White
    $snapshotName = "AddTypes $(Get-Date -Format 'yyyyMMdd HHmmss')"
    $snapshot = New-TCMSnapshot -DisplayName $snapshotName -Resources $newTypes -Wait

    $snapshotStatus = if ($snapshot -is [System.Collections.IDictionary]) { $snapshot['status'] } else { $snapshot.status }
    $snapshotId = if ($snapshot -is [System.Collections.IDictionary]) { $snapshot['id'] } else { $snapshot.id }

    if ($snapshotStatus -notin @('succeeded', 'succeededWithWarnings', 'partiallySuccessful')) {
        Write-Error "Snapshot failed with status: $snapshotStatus"
        return
    }

    # ── Convert new types to baseline resources ─────────────────────
    Write-Host 'Converting new resources...' -ForegroundColor White
    $snapshotContent = Get-TCMSnapshot -Id $snapshotId -IncludeContent
    $newBaseline = ConvertTo-TCMBaseline -SnapshotContent $snapshotContent -Profile Full -DisplayName 'temp'

    $newResources = @()
    if ($newBaseline -and $newBaseline.Resources) {
        $newResources = @($newBaseline.Resources)
    }

    Write-Host "  Found $($newResources.Count) resource instances in new types" -ForegroundColor DarkGray

    # ── Merge baselines ─────────────────────────────────────────────
    Write-Host 'Merging into existing baseline...' -ForegroundColor White
    $mergedResources = [System.Collections.Generic.List[object]]::new()

    # Keep all existing resources unchanged
    foreach ($r in $existingResources) {
        $mergedResources.Add($r)
    }

    # Add new resources
    foreach ($r in $newResources) {
        $mergedResources.Add($r)
    }

    $mergedBaseline = @{
        DisplayName = $mName
        Resources   = $mergedResources
    }

    # Quota check
    $dailyCost = $mergedResources.Count * 4
    $quotaPercent = [math]::Round(($dailyCost / 800) * 100, 1)
    $color = if ($quotaPercent -gt 80) { 'Red' } elseif ($quotaPercent -gt 50) { 'Yellow' } else { 'Green' }
    Write-Host "  Merged: $($mergedResources.Count) total resources (was $($existingResources.Count))" -ForegroundColor Cyan
    Write-Host "  Quota impact: $dailyCost / 800 per day ($quotaPercent%)" -ForegroundColor $color

    if ($quotaPercent -gt 100) {
        Write-Warning "Merged baseline exceeds daily quota! Consider removing low-value types with -ExcludeResources on ConvertTo-TCMBaseline."
    }

    # ── Update the monitor ──────────────────────────────────────────
    Write-Host 'Updating monitor...' -ForegroundColor White
    Update-TCMMonitor -Id $mId -Baseline $mergedBaseline -Confirm:$false

    # ── Clean up snapshot ───────────────────────────────────────────
    Remove-TCMSnapshot -Id $snapshotId -Confirm:$false 2>$null

    # ── Done ────────────────────────────────────────────────────────
    Write-Host ''
    Write-Host '✅ Monitor expanded successfully!' -ForegroundColor Green
    Write-Host "   $($existingResources.Count) existing + $($newResources.Count) new = $($mergedResources.Count) total resources" -ForegroundColor White
    Write-Host "   $($newTypes.Count) resource types added from: $($templateNames -join ', ')" -ForegroundColor White
    Write-Host ''
    Write-Host '   Existing drift records were cleared but will be re-detected within 6 hours.' -ForegroundColor DarkGray
    Write-Host '   Next: Get-TCMQuota to verify quota | Show-TCMDrift after 6h' -ForegroundColor DarkGray
    Write-Host ''
}
