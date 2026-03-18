function Export-TCMDriftReport {
    <#
    .SYNOPSIS
        Generate an HTML drift report with admin portal deep links.
    .DESCRIPTION
        Creates a self-contained HTML report showing:
        - Monitor overview and status
        - Active drifts with property-level detail
        - Baseline resource inventory
        - Quota dashboard
        - Deep links to Entra/Exchange/Intune/Teams admin portals for remediation

        Works with or without active drifts — use it as a status dashboard.
    .PARAMETER OutputPath
        Path for the HTML file. Defaults to ./EasyTCM-Report-<timestamp>.html
    .PARAMETER Open
        Open the report in the default browser after generating.
    .PARAMETER MonitorId
        Report on a specific monitor. If omitted, reports on all monitors.
    .EXAMPLE
        Export-TCMDriftReport -Open
    .EXAMPLE
        Export-TCMDriftReport -OutputPath "./reports/drift-report.html" -MonitorId $id
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath,

        [switch]$Open,

        [string]$MonitorId
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    if (-not $OutputPath) {
        $OutputPath = "./EasyTCM-Report-$timestamp.html"
    }

    Write-Host 'Generating EasyTCM drift report...' -ForegroundColor Cyan

    # Gather data
    $monitors = if ($MonitorId) {
        @(Get-TCMMonitor -Id $MonitorId)
    } else {
        $all = Get-TCMMonitor
        if (-not $all) { @() } else { @($all) }
    }

    $drifts = @(Get-TCMDrift)
    $quota = Get-TCMQuota

    # Build monitor details with baselines
    $monitorData = foreach ($m in $monitors) {
        $mId = if ($m -is [System.Collections.IDictionary]) { $m['id'] } else { $m.id }
        $mDn = if ($m -is [System.Collections.IDictionary]) { $m['displayName'] } else { $m.displayName }
        $mSt = if ($m -is [System.Collections.IDictionary]) { $m['status'] } else { $m.status }
        $mCreated = if ($m -is [System.Collections.IDictionary]) { $m['createdDateTime'] } else { $m.createdDateTime }

        $baseline = $null
        $resourceCount = 0
        try {
            $baseline = Invoke-TCMGraphRequest -Endpoint "configurationMonitors/$mId/baseline"
            $resources = if ($baseline.Resources) { $baseline.Resources } elseif ($baseline.resources) { $baseline.resources } else { @() }
            $resourceCount = @($resources).Count
        } catch { Write-Debug "Could not retrieve baseline for monitor ${mId}: $_" }

        [PSCustomObject]@{
            Id            = $mId
            DisplayName   = $mDn
            Status        = $mSt
            Created       = $mCreated
            ResourceCount = $resourceCount
            Resources     = $resources
            Drifts        = @($drifts | Where-Object {
                $did = if ($_ -is [System.Collections.IDictionary]) { $_['monitorId'] } else { $_.monitorId }
                $did -eq $mId
            })
        }
    }

    # Admin portal deep links by resource type
    $portalLinks = @{
        'microsoft.entra.conditionalaccesspolicy'                    = 'https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies'
        'microsoft.entra.namedlocationpolicy'                        = 'https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/NamedLocations'
        'microsoft.entra.authenticationmethodpolicy'                 = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods'
        'microsoft.entra.authorizationpolicy'                        = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/TenantOverview.ReactView'
        'microsoft.entra.crosstenantaccesspolicy'                    = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CompanyRelationshipsMenuBlade/~/CrossTenantAccessSettings'
        'microsoft.entra.crosstenantaccesspolicyconfigurationpartner'= 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CompanyRelationshipsMenuBlade/~/CrossTenantAccessSettings'
        'microsoft.exchange.transportrule'                           = 'https://admin.exchange.microsoft.com/#/transportrules'
        'microsoft.exchange.accepteddomain'                          = 'https://admin.exchange.microsoft.com/#/accepteddomains'
        'microsoft.teams.meetingpolicy'                              = 'https://admin.teams.microsoft.com/policies/meetings'
        'microsoft.securityandcompliance.dlpcompliancepolicy'            = 'https://compliance.microsoft.com/datalossprevention'
        'microsoft.securityandcompliance.retentioncompliancepolicy'      = 'https://compliance.microsoft.com/informationgovernance'
        'microsoft.securityandcompliance.labelpolicy'                    = 'https://compliance.microsoft.com/informationprotection'
    }

    # Build HTML
    $totalDrifts = $drifts.Count
    $statusColor = if ($totalDrifts -gt 0) { '#e74c3c' } else { '#27ae60' }
    $statusIcon = if ($totalDrifts -gt 0) { '&#9888;' } else { '&#10004;' }
    $statusText = if ($totalDrifts -gt 0) { "$totalDrifts Active Drift(s)" } else { 'No Active Drifts' }

    $quotaMonitorPct = if ($quota.MonitorLimit -gt 0) { [math]::Round(($quota.MonitorCount / $quota.MonitorLimit) * 100) } else { 0 }
    $quotaDailyPct = if ($quota.DailyResourceLimit -gt 0) { [math]::Round(($quota.DailyResourceUsage / $quota.DailyResourceLimit) * 100) } else { 0 }
    $quotaSnapPct = if ($quota.SnapshotJobLimit -gt 0) { [math]::Round(($quota.SnapshotJobCount / $quota.SnapshotJobLimit) * 100) } else { 0 }

    # Generate drift rows
    $driftRows = ''
    foreach ($monitor in $monitorData) {
        foreach ($drift in $monitor.Drifts) {
            $dDn = if ($drift -is [System.Collections.IDictionary]) { $drift['displayName'] } else { $drift.displayName }
            $dType = if ($drift -is [System.Collections.IDictionary]) { $drift['resourceType'] } else { $drift.resourceType }
            $dStatus = if ($drift -is [System.Collections.IDictionary]) { $drift['status'] } else { $drift.status }
            $dProps = if ($drift -is [System.Collections.IDictionary]) { $drift['driftedProperties'] } else { $drift.driftedProperties }

            $portalLink = if ($portalLinks.ContainsKey($dType)) { $portalLinks[$dType] } else { '#' }
            $propCount = @($dProps).Count

            $propDetails = ''
            foreach ($p in $dProps) {
                $pName = if ($p -is [System.Collections.IDictionary]) { $p['propertyName'] } else { $p.propertyName }
                $pExpected = if ($p -is [System.Collections.IDictionary]) { $p['expectedValue'] } else { $p.expectedValue }
                $pActual = if ($p -is [System.Collections.IDictionary]) { $p['currentValue'] } else { $p.currentValue }
                $propDetails += "<div class='prop-row'><span class='prop-name'>$([System.Web.HttpUtility]::HtmlEncode($pName))</span><span class='prop-expected'>$([System.Web.HttpUtility]::HtmlEncode("$pExpected"))</span><span class='prop-actual'>$([System.Web.HttpUtility]::HtmlEncode("$pActual"))</span></div>"
            }

            $driftRows += @"
            <tr>
                <td>$([System.Web.HttpUtility]::HtmlEncode($monitor.DisplayName))</td>
                <td>$([System.Web.HttpUtility]::HtmlEncode($dDn))</td>
                <td><code>$([System.Web.HttpUtility]::HtmlEncode($dType))</code></td>
                <td class="center">$propCount</td>
                <td><span class="badge badge-$dStatus">$dStatus</span></td>
                <td><a href="$portalLink" target="_blank" class="portal-link">Open Portal &#8599;</a></td>
            </tr>
            <tr class="prop-detail-row"><td colspan="6">$propDetails</td></tr>
"@
        }
    }

    if (-not $driftRows) {
        $driftRows = '<tr><td colspan="6" class="center no-drift">No active drifts detected. Your tenant configuration matches all baselines.</td></tr>'
    }

    # Generate monitor/baseline rows
    $monitorRows = ''
    foreach ($monitor in $monitorData) {
        $statusBadge = if ($monitor.Status -eq 'active') { 'active' } else { 'inactive' }
        $monitorRows += "<tr><td>$([System.Web.HttpUtility]::HtmlEncode($monitor.DisplayName))</td><td><span class='badge badge-$statusBadge'>$($monitor.Status)</span></td><td class='center'>$($monitor.ResourceCount)</td><td>$($monitor.Created)</td><td><code>$($monitor.Id)</code></td></tr>"

        # Resource breakdown
        if ($monitor.Resources) {
            $grouped = @($monitor.Resources) | Group-Object {
                if ($_ -is [System.Collections.IDictionary]) { $_['ResourceType'] ?? $_['resourceType'] } else { $_.ResourceType ?? $_.resourceType }
            }
            foreach ($g in $grouped | Sort-Object Name) {
                $portalLink = if ($portalLinks.ContainsKey($g.Name)) { "<a href='$($portalLinks[$g.Name])' target='_blank'>&#8599;</a>" } else { '' }
                $monitorRows += "<tr class='resource-row'><td colspan='2' style='padding-left:2rem'><code>$([System.Web.HttpUtility]::HtmlEncode($g.Name))</code> $portalLink</td><td class='center'>$($g.Count)</td><td colspan='2'></td></tr>"
            }
        }
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>EasyTCM Drift Report — $timestamp</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; background: #f0f2f5; color: #1a1a2e; line-height: 1.6; }
  .container { max-width: 1100px; margin: 0 auto; padding: 2rem 1rem; }
  header { text-align: center; margin-bottom: 2rem; }
  header h1 { font-size: 1.8rem; color: #1a1a2e; }
  header h1 span { color: #0078d4; }
  .subtitle { color: #666; font-size: 0.9rem; margin-top: 0.3rem; }
  .status-banner { background: $statusColor; color: white; padding: 1rem 1.5rem; border-radius: 10px; text-align: center; font-size: 1.3rem; margin-bottom: 2rem; }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 1rem; margin-bottom: 2rem; }
  .card { background: white; border-radius: 10px; padding: 1.2rem; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
  .card h3 { font-size: 0.8rem; text-transform: uppercase; color: #888; letter-spacing: 0.05em; margin-bottom: 0.5rem; }
  .card .value { font-size: 1.8rem; font-weight: 700; }
  .card .detail { font-size: 0.8rem; color: #888; margin-top: 0.2rem; }
  .progress-bar { height: 6px; background: #e8e8e8; border-radius: 3px; margin-top: 0.5rem; overflow: hidden; }
  .progress-fill { height: 100%; border-radius: 3px; transition: width 0.3s; }
  .pf-green { background: #27ae60; }
  .pf-yellow { background: #f39c12; }
  .pf-red { background: #e74c3c; }
  section { margin-bottom: 2rem; }
  section h2 { font-size: 1.2rem; margin-bottom: 1rem; padding-bottom: 0.5rem; border-bottom: 2px solid #0078d4; }
  table { width: 100%; border-collapse: collapse; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
  th { background: #f8f9fa; text-align: left; padding: 0.8rem 1rem; font-size: 0.8rem; text-transform: uppercase; color: #666; letter-spacing: 0.03em; }
  td { padding: 0.7rem 1rem; border-top: 1px solid #eee; font-size: 0.9rem; }
  .center { text-align: center; }
  .badge { padding: 0.2rem 0.6rem; border-radius: 12px; font-size: 0.75rem; font-weight: 600; }
  .badge-active { background: #d4edda; color: #155724; }
  .badge-inactive { background: #f8d7da; color: #721c24; }
  .badge-fixed { background: #d1ecf1; color: #0c5460; }
  code { background: #f1f3f5; padding: 0.15rem 0.4rem; border-radius: 3px; font-size: 0.8rem; }
  .portal-link { color: #0078d4; text-decoration: none; font-weight: 600; }
  .portal-link:hover { text-decoration: underline; }
  .resource-row td { background: #f8f9fa; font-size: 0.85rem; color: #555; }
  .prop-detail-row td { padding: 0.3rem 1rem 0.8rem 2rem; background: #fafbfc; }
  .prop-row { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 0.5rem; padding: 0.2rem 0; font-size: 0.8rem; border-bottom: 1px solid #f0f0f0; }
  .prop-name { font-weight: 600; color: #333; }
  .prop-expected { color: #27ae60; }
  .prop-expected::before { content: 'Expected: '; font-weight: 600; }
  .prop-actual { color: #e74c3c; }
  .prop-actual::before { content: 'Actual: '; font-weight: 600; }
  .no-drift { color: #27ae60; font-weight: 600; padding: 2rem !important; font-size: 1rem; }
  footer { text-align: center; color: #999; font-size: 0.8rem; margin-top: 2rem; padding-top: 1rem; border-top: 1px solid #ddd; }
  footer a { color: #0078d4; text-decoration: none; }
  @media (max-width: 600px) { .grid { grid-template-columns: 1fr; } .prop-row { grid-template-columns: 1fr; } }
</style>
</head>
<body>
<div class="container">
  <header>
    <h1>&#128737; <span>EasyTCM</span> Drift Report</h1>
    <div class="subtitle">Generated $(Get-Date -Format 'dddd, MMMM d, yyyy \a\t HH:mm:ss') UTC</div>
  </header>

  <div class="status-banner">$statusIcon $statusText</div>

  <div class="grid">
    <div class="card">
      <h3>Monitors</h3>
      <div class="value">$($quota.MonitorCount) <span style="font-size:0.9rem;color:#888">/ $($quota.MonitorLimit)</span></div>
      <div class="progress-bar"><div class="progress-fill $(if($quotaMonitorPct -gt 80){'pf-red'}elseif($quotaMonitorPct -gt 50){'pf-yellow'}else{'pf-green'})" style="width:$([math]::Min($quotaMonitorPct,100))%"></div></div>
      <div class="detail">$quotaMonitorPct% used</div>
    </div>
    <div class="card">
      <h3>Daily Resources</h3>
      <div class="value">$($quota.DailyResourceUsage) <span style="font-size:0.9rem;color:#888">/ $($quota.DailyResourceLimit)</span></div>
      <div class="progress-bar"><div class="progress-fill $(if($quotaDailyPct -gt 80){'pf-red'}elseif($quotaDailyPct -gt 50){'pf-yellow'}else{'pf-green'})" style="width:$([math]::Min($quotaDailyPct,100))%"></div></div>
      <div class="detail">$quotaDailyPct% of 800/day quota</div>
    </div>
    <div class="card">
      <h3>Snapshot Jobs</h3>
      <div class="value">$($quota.SnapshotJobCount) <span style="font-size:0.9rem;color:#888">/ $($quota.SnapshotJobLimit)</span></div>
      <div class="progress-bar"><div class="progress-fill $(if($quotaSnapPct -gt 80){'pf-red'}elseif($quotaSnapPct -gt 50){'pf-yellow'}else{'pf-green'})" style="width:$([math]::Min($quotaSnapPct,100))%"></div></div>
      <div class="detail">$quotaSnapPct% used</div>
    </div>
    <div class="card">
      <h3>Active Drifts</h3>
      <div class="value" style="color:$statusColor">$totalDrifts</div>
      <div class="detail">across $(@($monitors).Count) monitor(s)</div>
    </div>
  </div>

  <section>
    <h2>&#9888; Drifts</h2>
    <table>
      <thead><tr><th>Monitor</th><th>Resource</th><th>Type</th><th class="center">Properties</th><th>Status</th><th>Portal</th></tr></thead>
      <tbody>$driftRows</tbody>
    </table>
  </section>

  <section>
    <h2>&#128270; Monitors &amp; Baseline Resources</h2>
    <table>
      <thead><tr><th>Monitor</th><th>Status</th><th class="center">Resources</th><th>Created</th><th>ID</th></tr></thead>
      <tbody>$monitorRows</tbody>
    </table>
  </section>

  <footer>
    Generated by <a href="https://github.com/kayasax/EasyTCM">EasyTCM</a> — TCM as Maester's Drift Engine<br>
    Monitor runs every 6 hours at fixed UTC times: 6 AM, 12 PM, 6 PM, 12 AM
  </footer>
</div>
</body>
</html>
"@

    $html | Set-Content -Path $OutputPath -Encoding utf8
    Write-Host "Report saved to: $OutputPath" -ForegroundColor Green

    if ($Open) {
        Start-Process $OutputPath
    }

    [PSCustomObject]@{
        Path       = (Resolve-Path $OutputPath).Path
        Monitors   = @($monitors).Count
        Drifts     = $totalDrifts
        Generated  = Get-Date
    }
}
