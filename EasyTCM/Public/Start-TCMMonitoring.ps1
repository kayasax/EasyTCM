function Start-TCMMonitoring {
    <#
    .SYNOPSIS
        One-command setup: from zero to monitoring in a single run.
    .DESCRIPTION
        Guided wizard that handles the entire first-time TCM setup:
        1. Checks Graph connection (prompts if missing)
        2. Creates the TCM service principal and grants permissions (Initialize-TCM)
        3. Takes a snapshot of the current tenant configuration
        4. Converts the snapshot to a baseline
        5. Creates a monitor that checks for drift every 6 hours

        After this, TCM monitors your tenant automatically. Use Watch-TCMDrift
        to check the results.
    .PARAMETER Profile
        Which monitoring profile to use:
        - SecurityCritical: CA policies, authentication methods, named locations (14 types)
        - Recommended: all of SecurityCritical + Exchange, DLP, compliance (29 types)
        Default: Recommended
    .PARAMETER MonitorName
        Custom name for the monitor. Default: "EasyTCM <Profile>"
    .PARAMETER SkipInitialize
        Skip the service principal setup (use if already done).
    .EXAMPLE
        # Full guided setup — just run this:
        Start-TCMMonitoring

    .EXAMPLE
        # Security-focused monitoring only
        Start-TCMMonitoring -Profile SecurityCritical

    .EXAMPLE
        # Already initialized, re-creating the monitor
        Start-TCMMonitoring -SkipInitialize
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('SecurityCritical', 'Recommended')]
        [string]$Profile = 'Recommended',

        [string]$MonitorName,

        [switch]$SkipInitialize
    )

    if (-not $MonitorName) {
        $MonitorName = "EasyTCM $Profile"
    }

    Write-Host ''
    Write-Host '╔══════════════════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '║         EasyTCM — Start Monitoring Setup            ║' -ForegroundColor Cyan
    Write-Host '╚══════════════════════════════════════════════════════╝' -ForegroundColor Cyan
    Write-Host ''

    # ── Step 1: Check Graph connection ──────────────────────────────
    Write-Host '[ 1/5 ] Checking Microsoft Graph connection...' -ForegroundColor White
    $ctx = Get-MgContext
    if (-not $ctx) {
        Write-Host '  Not connected. Connecting to Microsoft Graph...' -ForegroundColor Yellow
        Connect-MgGraph -Scopes 'Application.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All', 'RoleManagement.ReadWrite.Directory', 'ConfigurationMonitoring.ReadWrite.All' -NoWelcome
        $ctx = Get-MgContext
        if (-not $ctx) {
            Write-Error 'Failed to connect to Microsoft Graph. Please run Connect-MgGraph manually.'
            return
        }
    }
    Write-Host "  Connected as $($ctx.Account) to tenant $($ctx.TenantId)" -ForegroundColor Green

    # ── Step 2: Initialize TCM (service principal + permissions) ────
    if (-not $SkipInitialize) {
        Write-Host ''
        Write-Host '[ 2/5 ] Setting up TCM service principal and permissions...' -ForegroundColor White
        $init = Initialize-TCM
        if ($init.Status -eq 'Ready') {
            Write-Host '  TCM service principal is ready.' -ForegroundColor Green
        }
        elseif ($init.Status -eq 'SetupCompleteValidationFailed') {
            Write-Host '  Service principal created but validation failed.' -ForegroundColor Yellow
            Write-Host '  Permissions may take a few minutes to propagate. Continuing...' -ForegroundColor Yellow
        }
        else {
            Write-Warning "  Unexpected status: $($init.Status)"
        }
    }
    else {
        Write-Host ''
        Write-Host '[ 2/5 ] Skipping initialization (already done).' -ForegroundColor DarkGray
    }

    # ── Step 3: Check for existing monitors ─────────────────────────
    Write-Host ''
    Write-Host '[ 3/5 ] Checking for existing monitors...' -ForegroundColor White
    $existingMonitors = Get-TCMMonitor 2>$null
    $existingMatch = $existingMonitors | Where-Object { $_.displayName -eq $MonitorName }
    if ($existingMatch) {
        Write-Host "  Monitor '$MonitorName' already exists (Id: $($existingMatch.id))." -ForegroundColor Green
        Write-Host '  Your tenant is already being monitored!' -ForegroundColor Green
        Write-Host ''
        Write-Host '  Next steps:' -ForegroundColor White
        Write-Host '    Watch-TCMDrift                  # check for drift' -ForegroundColor DarkGray
        Write-Host '    Watch-TCMDrift -Report           # HTML report' -ForegroundColor DarkGray
        Write-Host '    Update-TCMBaseline               # after approved changes' -ForegroundColor DarkGray
        return $existingMatch
    }

    # ── Step 4: Take snapshot and create baseline ───────────────────
    Write-Host ''
    Write-Host "[ 4/5 ] Taking a snapshot of your tenant ($Profile profile)..." -ForegroundColor White
    $snapshotName = "Baseline $(Get-Date -Format 'yyyyMMdd HHmmss')"
    $snapshot = New-TCMSnapshot -DisplayName $snapshotName -Wait
    if (-not $snapshot -or $snapshot.status -notin @('succeeded', 'succeededWithWarnings')) {
        Write-Error "Snapshot failed with status: $($snapshot.status). Check Get-TCMSnapshot for details."
        return
    }

    Write-Host '  Converting snapshot to baseline...' -ForegroundColor DarkGray
    $snapshotContent = Get-TCMSnapshot -Id $snapshot.id -IncludeContent
    $baseline = ConvertTo-TCMBaseline -SnapshotContent $snapshotContent -DisplayName $MonitorName -Profile $Profile

    # ── Step 5: Create the monitor ──────────────────────────────────
    Write-Host ''
    Write-Host '[ 5/5 ] Creating monitor...' -ForegroundColor White
    $monitor = New-TCMMonitor -DisplayName $MonitorName -Baseline $baseline

    # Clean up snapshot
    Remove-TCMSnapshot -Id $snapshot.id -Confirm:$false 2>$null

    # ── Done! ───────────────────────────────────────────────────────
    Write-Host ''
    Write-Host '╔══════════════════════════════════════════════════════╗' -ForegroundColor Green
    Write-Host '║         ✅ Monitoring is now active!                 ║' -ForegroundColor Green
    Write-Host '╚══════════════════════════════════════════════════════╝' -ForegroundColor Green
    Write-Host ''
    Write-Host "  Monitor : $MonitorName" -ForegroundColor White
    Write-Host "  Profile : $Profile ($($baseline.resources.Count) resources)" -ForegroundColor White
    Write-Host "  Schedule: TCM checks every 6 hours automatically" -ForegroundColor White
    Write-Host ''
    Write-Host '  What happens next:' -ForegroundColor White
    Write-Host '  • TCM compares your tenant against this baseline every 6 hours' -ForegroundColor DarkGray
    Write-Host '  • Any unauthorized changes are flagged as "drift"' -ForegroundColor DarkGray
    Write-Host '  • Run Watch-TCMDrift anytime to see the current state' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Quick commands:' -ForegroundColor White
    Write-Host '    Watch-TCMDrift                  # console summary' -ForegroundColor DarkGray
    Write-Host '    Watch-TCMDrift -Report           # HTML report' -ForegroundColor DarkGray
    Write-Host '    Watch-TCMDrift -Maester           # Maester integration' -ForegroundColor DarkGray
    Write-Host '    Update-TCMBaseline               # after approved changes' -ForegroundColor DarkGray
    Write-Host '    Compare-TCMBaseline              # find untracked resources' -ForegroundColor DarkGray
    Write-Host ''

    $monitor
}
