function Show-TCMMonitor {
    <#
    .SYNOPSIS
        Inspect what your TCM monitor is watching — resource types, workloads, and quota.
    .DESCRIPTION
        Shows a human-readable breakdown of monitored resource types grouped by workload,
        with descriptions, severity ratings, and admin portal links.

        Without parameters:  Shows the first (or only) active monitor.
        With -Profile:       Previews a built-in profile definition without needing a monitor.
        With -Browser:       Opens an interactive HTML page with full details.
        With -Detailed:      Adds descriptions and admin portal links to console output.

    .PARAMETER MonitorId
        Show a specific monitor by ID. Defaults to the first monitor found.
    .PARAMETER Profile
        Preview a built-in profile definition (SecurityCritical, Recommended, Full)
        without needing an active monitor. Shows which resource types are included.
    .PARAMETER Detailed
        Include descriptions and admin portal links in the console output.
    .PARAMETER Browser
        Open an interactive HTML page in the default browser instead of console output.
    .EXAMPLE
        Show-TCMMonitor
        # Quick overview of your monitor
    .EXAMPLE
        Show-TCMMonitor -Detailed
        # Full details with descriptions and admin links
    .EXAMPLE
        Show-TCMMonitor -ProfileName SecurityCritical
        # Preview what SecurityCritical monitors
    .EXAMPLE
        Show-TCMMonitor -Browser
        # Open rich HTML view in browser
    #>
    [CmdletBinding(DefaultParameterSetName = 'Monitor')]
    param(
        [Parameter(ParameterSetName = 'Monitor')]
        [string]$MonitorId,

        [Parameter(ParameterSetName = 'Profile', Mandatory)]
        [ValidateSet('SecurityCritical', 'Recommended', 'Full')]
        [string]$ProfileName,

        [switch]$Detailed,
        [switch]$Browser
    )

    $catalog = Get-TCMResourceTypeCatalog

    # ── Profile preview mode (no monitor needed) ──────────────────
    if ($Browser) {
        Write-Warning 'HTML browser mode will be available in a future update. Use Edit-TCMMonitor for interactive editing.'
        return
    }

    if ($PSCmdlet.ParameterSetName -eq 'Profile') {
        Show-TCMProfilePreview -ProfileName $ProfileName -Catalog $catalog -Detailed:$Detailed
        return
    }

    # ── Monitor mode ──────────────────────────────────────────────
    $monitors = @(Get-TCMMonitor)
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

    # ── Build display data ────────────────────────────────────────
    $monitoredSet = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@($monitor.MonitoredTypes),
        [StringComparer]::OrdinalIgnoreCase
    )

    # Group catalog entries by workload
    $workloads = @{}
    foreach ($key in $catalog.Keys) {
        $entry = $catalog[$key]
        $wl = $entry.Workload
        if (-not $workloads.ContainsKey($wl)) { $workloads[$wl] = @() }
        $workloads[$wl] += @{ Key = $key; Entry = $entry; Monitored = $monitoredSet.Contains($key) }
    }

    # ── Console output ────────────────────────────────────────────
    $statusColor = if ($monitor.Status -eq 'active') { 'Green' } else { 'Yellow' }
    $statusIcon  = if ($monitor.Status -eq 'active') { '●' } else { '○' }

    Write-Host ''
    Write-Host "  $statusIcon $($monitor.DisplayName)" -ForegroundColor $statusColor -NoNewline
    Write-Host " — $($monitor.ResourceCount) resources across $($monitoredSet.Count) types ($($monitor.Status))" -ForegroundColor Gray
    Write-Host "    Frequency: every $($monitor.Frequency) | Created: $($monitor.CreatedDateTime)" -ForegroundColor DarkGray
    Write-Host ''

    $workloadOrder = @('Entra', 'Exchange', 'Teams', 'Intune', 'SecurityAndCompliance')
    $notMonitored = @()

    foreach ($wl in $workloadOrder) {
        if (-not $workloads.ContainsKey($wl)) { continue }
        $types = $workloads[$wl] | Sort-Object { $_.Entry.DisplayName }
        $monCount = @($types | Where-Object { $_.Monitored }).Count
        $totalCount = $types.Count

        # Friendly workload name
        $wlDisplay = switch ($wl) {
            'Entra'                  { 'Entra ID' }
            'Exchange'               { 'Exchange Online' }
            'Teams'                  { 'Microsoft Teams' }
            'Intune'                 { 'Microsoft Intune' }
            'SecurityAndCompliance'  { 'Security & Compliance' }
            default                  { $wl }
        }

        Write-Host "  $wlDisplay ($monCount/$totalCount types)" -ForegroundColor White

        foreach ($t in $types) {
            $e = $t.Entry
            if ($t.Monitored) {
                Write-Host "    ✅ $($e.DisplayName)" -ForegroundColor Green

                if ($Detailed) {
                    Write-Host "       $($e.Description)" -ForegroundColor DarkGray
                    if ($e.AdminPortal) {
                        Write-Host "       🔗 $($e.AdminPortal)" -ForegroundColor DarkCyan
                    }
                }
            } else {
                $notMonitored += $t
            }
        }
        Write-Host ''
    }

    # Not monitored section
    if ($notMonitored.Count -gt 0) {
        Write-Host "  Not monitored ($($notMonitored.Count) types available)" -ForegroundColor DarkGray
        foreach ($t in ($notMonitored | Sort-Object { $_.Entry.Workload }, { $_.Entry.DisplayName })) {
            $e = $t.Entry
            $quotaWarn = if ($e.QuotaNote) { " ⚠️ $($e.QuotaNote)" } else { '' }
            Write-Host "    ⬚ $($e.DisplayName)$quotaWarn" -ForegroundColor DarkGray

            if ($Detailed) {
                Write-Host "       $($e.Description)" -ForegroundColor DarkGray
                if ($e.AdminPortal) {
                    Write-Host "       🔗 $($e.AdminPortal)" -ForegroundColor DarkCyan
                }
            }
        }
        Write-Host ''
    }

    # Quota hint
    Write-Host "  Quota: $($monitor.ResourceCount) resources per run" -ForegroundColor DarkGray
    Write-Host "  💡 Run " -ForegroundColor DarkGray -NoNewline
    Write-Host "Show-TCMMonitor -Detailed" -ForegroundColor Cyan -NoNewline
    Write-Host " for descriptions and admin links" -ForegroundColor DarkGray
    Write-Host ''
}

function Show-TCMProfilePreview {
    <# .SYNOPSIS Internal: shows a profile definition without a monitor. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProfileName,
        [Parameter(Mandatory)][hashtable]$Catalog,
        [switch]$Detailed
    )

    $profiles = Get-TCMMonitoringProfile
    $profileTypes = switch ($ProfileName) {
        'SecurityCritical' { $profiles.SecurityCritical }
        'Recommended'      { $profiles.Recommended }
        'Full'             { $Catalog.Keys }
    }

    $profileSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($t in $profileTypes) { [void]$profileSet.Add($t) }

    Write-Host ''
    Write-Host "  📊 Profile: $ProfileName — $($profileSet.Count) resource types" -ForegroundColor Cyan
    Write-Host ''

    $workloadOrder = @('Entra', 'Exchange', 'Teams', 'Intune', 'SecurityAndCompliance')

    foreach ($wl in $workloadOrder) {
        $types = $Catalog.GetEnumerator() |
            Where-Object { $_.Value.Workload -eq $wl -and $profileSet.Contains($_.Key) } |
            Sort-Object { $_.Value.DisplayName }

        if ($types.Count -eq 0) { continue }

        $wlDisplay = switch ($wl) {
            'Entra'                  { 'Entra ID' }
            'Exchange'               { 'Exchange Online' }
            'Teams'                  { 'Microsoft Teams' }
            'Intune'                 { 'Microsoft Intune' }
            'SecurityAndCompliance'  { 'Security & Compliance' }
            default                  { $wl }
        }

        Write-Host "  $wlDisplay ($($types.Count) types)" -ForegroundColor White

        foreach ($t in $types) {
            $e = $t.Value
            $severityColor = switch ($e.Severity) {
                'SHALL'  { 'Red' }
                'SHOULD' { 'Yellow' }
                default  { 'Gray' }
            }
            Write-Host "    ✅ $($e.DisplayName)" -ForegroundColor Green -NoNewline
            Write-Host " [$($e.Severity)]" -ForegroundColor $severityColor

            if ($Detailed) {
                Write-Host "       $($e.Description)" -ForegroundColor DarkGray
                if ($e.AdminPortal) {
                    Write-Host "       🔗 $($e.AdminPortal)" -ForegroundColor DarkCyan
                }
            }
        }
        Write-Host ''
    }
}
