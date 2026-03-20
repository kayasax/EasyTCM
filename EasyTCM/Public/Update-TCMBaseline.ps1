function Update-TCMBaseline {
    <#
    .SYNOPSIS
        After approved changes, take a fresh snapshot and update the monitor baseline.
    .DESCRIPTION
        When you intentionally change your tenant configuration (e.g., adding a CA
        policy, updating authentication methods), those changes show as drift until
        you update the baseline.

        This cmdlet automates the rebaseline workflow:
        1. Takes a fresh snapshot of the current tenant
        2. Converts it to a baseline using the same profile
        3. Updates the monitor with the new baseline

        ⚠  WARNING: Updating the baseline deletes ALL existing drift records for the
        monitor. Only run this after confirming all current drift is intentional.

        When to run this:
        • After deploying approved policy changes
        • After Show-TCMDrift confirms only expected drift
        • After onboarding new services that add resources

        When NOT to run this:
        • If you see unexpected drift — investigate first!
        • Before reviewing current drift with Show-TCMDrift
    .PARAMETER MonitorId
        The monitor to update. If omitted, updates the first active monitor.
    .PARAMETER Profile
        Monitoring profile for the new baseline. Should match the original.
        Default: Recommended
    .PARAMETER Force
        Skip the confirmation prompt.
    .EXAMPLE
        # Review drift, then rebaseline
        Show-TCMDrift
        Update-TCMBaseline

    .EXAMPLE
        # Rebaseline a specific monitor with SecurityCritical profile
        Update-TCMBaseline -MonitorId 'eca21d95-...' -Profile SecurityCritical

    .EXAMPLE
        # Non-interactive (scripts/automation)
        Update-TCMBaseline -Force
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [string]$MonitorId,

        [ValidateSet('SecurityCritical', 'Recommended', 'Full')]
        [string]$Profile = 'Recommended',

        [switch]$Force
    )

    Write-Host ''
    Write-Host '🔄 Update-TCMBaseline — Rebaseline after approved changes' -ForegroundColor Cyan
    Write-Host ''

    # ── Resolve monitor ─────────────────────────────────────────────
    Write-Host 'Retrieving current monitor...' -ForegroundColor White
    $monitor = if ($MonitorId) {
        Get-TCMMonitor -Id $MonitorId
    }
    else {
        $all = Get-TCMMonitor
        if ($all -is [array]) { $all[0] } else { $all }
    }

    if (-not $monitor) {
        Write-Error 'No monitor found. Create one first with Start-TCMMonitoring.'
        return
    }

    $mId = if ($monitor -is [System.Collections.IDictionary]) { $monitor['id'] } else { $monitor.id }
    $mName = if ($monitor -is [System.Collections.IDictionary]) { $monitor['displayName'] } else { $monitor.displayName }

    Write-Host "  Monitor: $mName" -ForegroundColor DarkGray
    Write-Host "  Profile: $Profile" -ForegroundColor DarkGray

    # ── Show current drift before rebaselining ──────────────────────
    $drifts = @(Get-TCMDrift -MonitorId $mId -Status 'active' 2>$null)
    if ($drifts.Count -gt 0) {
        Write-Host ''
        Write-Host "  ⚠️  $($drifts.Count) active drift(s) that will be cleared:" -ForegroundColor Yellow
        foreach ($d in $drifts | Select-Object -First 5) {
            $shortType = ($d.ResourceType -split '\.')[-1]
            Write-Host "    • $shortType — $($d.ResourceDisplay) ($($d.DriftedPropertyCount) changes)" -ForegroundColor Yellow
        }
        if ($drifts.Count -gt 5) {
            Write-Host "    ... and $($drifts.Count - 5) more" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host '  ✅ No active drift — baseline is already current.' -ForegroundColor Green
    }

    # ── Confirmation ────────────────────────────────────────────────
    if (-not $Force) {
        if (-not $PSCmdlet.ShouldProcess("Monitor '$mName'", 'Update baseline (deletes all existing drift records)')) {
            return
        }
    }

    # ── Take fresh snapshot ─────────────────────────────────────────
    Write-Host ''
    Write-Host 'Taking fresh snapshot...' -ForegroundColor White
    $snapshotName = "Rebaseline $(Get-Date -Format 'yyyyMMdd HHmmss')"
    $snapshot = New-TCMSnapshot -DisplayName $snapshotName -Wait

    $snapshotStatus = if ($snapshot -is [System.Collections.IDictionary]) { $snapshot['status'] } else { $snapshot.status }
    $snapshotId = if ($snapshot -is [System.Collections.IDictionary]) { $snapshot['id'] } else { $snapshot.id }

    if ($snapshotStatus -notin @('succeeded', 'succeededWithWarnings', 'partiallySuccessful')) {
        Write-Error "Snapshot failed with status: $snapshotStatus"
        return
    }

    # ── Convert to baseline ─────────────────────────────────────────
    Write-Host 'Converting snapshot to baseline...' -ForegroundColor White
    $snapshotContent = Get-TCMSnapshot -Id $snapshotId -IncludeContent
    $baseline = ConvertTo-TCMBaseline -SnapshotContent $snapshotContent -DisplayName $mName -Profile $Profile

    # ── Update the monitor ──────────────────────────────────────────
    Write-Host 'Updating monitor baseline...' -ForegroundColor White
    Update-TCMMonitor -Id $mId -Baseline $baseline -Confirm:$false

    # ── Clean up snapshot ───────────────────────────────────────────
    Remove-TCMSnapshot -Id $snapshotId -Confirm:$false 2>$null

    # ── Invalidate comparison cache ─────────────────────────────────
    if (Test-Path $script:CompareBaselineCachePath) {
        Remove-Item $script:CompareBaselineCachePath -Force 2>$null
    }

    # ── Done ────────────────────────────────────────────────────────
    Write-Host ''
    Write-Host '✅ Baseline updated successfully!' -ForegroundColor Green
    Write-Host "   $($baseline.Resources.Count) resources now monitored with '$Profile' profile." -ForegroundColor White
    Write-Host '   All previous drift records have been cleared.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '   Next: Show-TCMDrift to verify clean state.' -ForegroundColor DarkGray
    Write-Host ''
}
