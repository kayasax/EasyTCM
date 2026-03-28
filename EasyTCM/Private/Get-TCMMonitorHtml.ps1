function Get-TCMMonitorHtml {
    <#
    .SYNOPSIS
        Generate a self-contained HTML page for monitor inspection or editing.
    .DESCRIPTION
        Produces an HTML string used by Show-TCMMonitor -Browser (read-only)
        and Edit-TCMMonitor (interactive mode with checkboxes).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Catalog,

        [Parameter()]
        [string]$MonitorId,

        [Parameter()]
        [string]$MonitorDisplayName,

        [Parameter()]
        [string]$MonitorStatus = 'active',

        [Parameter()]
        [int]$ResourceCount = 0,

        [Parameter()]
        [string[]]$MonitoredTypes = @(),

        [Parameter()]
        [string]$ProfileLabel,

        [Parameter()]
        [ValidateSet('ReadOnly', 'Edit')]
        [string]$Mode = 'ReadOnly'
    )

    $isEdit = $Mode -eq 'Edit'
    $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')

    # Get profile definitions
    $profiles = Get-TCMMonitoringProfile
    $profileJson = @{
        SecurityCritical = @($profiles.SecurityCritical)
        Recommended      = @($profiles.Recommended)
        Full             = @($Catalog.Keys)
    } | ConvertTo-Json -Compress

    # Detect which profile the monitor's types belong to.
    # Strategy: find the SMALLEST profile that contains ALL baseline types.
    # This works regardless of monitor display name.
    $baselineSet = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@($MonitoredTypes),
        [StringComparer]::OrdinalIgnoreCase
    )
    $detectedProfileName = $ProfileLabel  # explicit label takes priority
    if (-not $detectedProfileName -and $baselineSet.Count -gt 0) {
        # Check smallest → largest: SecurityCritical, Recommended, Full
        $scSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@($profiles.SecurityCritical), [StringComparer]::OrdinalIgnoreCase)
        $recSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@($profiles.Recommended), [StringComparer]::OrdinalIgnoreCase)
        if ($baselineSet.IsSubsetOf($scSet)) {
            $detectedProfileName = 'SecurityCritical'
        } elseif ($baselineSet.IsSubsetOf($recSet)) {
            $detectedProfileName = 'Recommended'
        } else {
            # All types fit in Full by definition, but only call it Full
            # if the user actually monitors types outside Recommended
            $detectedProfileName = 'Full'
        }
    }

    # Build monitored set — expand to full profile if detected.
    # A Recommended monitor watches ALL Recommended types even if some had zero
    # resources at snapshot time (new resources appear as baseline drift).
    $monitoredSet = [System.Collections.Generic.HashSet[string]]::new($baselineSet, [StringComparer]::OrdinalIgnoreCase)
    if ($detectedProfileName) {
        $profileTypes = switch ($detectedProfileName) {
            'SecurityCritical' { $profiles.SecurityCritical }
            'Recommended'      { $profiles.Recommended }
            'Full'             { @($Catalog.Keys) }
        }
        foreach ($pt in $profileTypes) { [void]$monitoredSet.Add($pt) }
    }

    # Build workload sections HTML
    $workloadOrder = @('Entra', 'Exchange', 'Teams', 'Intune', 'SecurityAndCompliance')
    $workloadNames = @{
        Entra                 = 'Entra ID'
        Exchange              = 'Exchange Online'
        Teams                 = 'Microsoft Teams'
        Intune                = 'Microsoft Intune'
        SecurityAndCompliance = 'Security &amp; Compliance'
    }

    $sectionsHtml = ''
    foreach ($wl in $workloadOrder) {
        $types = $Catalog.GetEnumerator() |
            Where-Object { $_.Value.Workload -eq $wl } |
            Sort-Object { $_.Value.DisplayName }

        if ($types.Count -eq 0) { continue }

        $wlDisplay = $workloadNames[$wl]
        $monCount = @($types | Where-Object { $monitoredSet.Contains($_.Key) }).Count
        $totalCount = $types.Count

        $rowsHtml = ''
        foreach ($t in $types) {
            $key = [System.Web.HttpUtility]::HtmlEncode($t.Key)
            $e = $t.Value
            $dn = [System.Web.HttpUtility]::HtmlEncode($e.DisplayName)
            $desc = [System.Web.HttpUtility]::HtmlEncode($e.Description)
            $isMonitored = $monitoredSet.Contains($t.Key)
            $checkedAttr = if ($isMonitored) { ' checked' } else { '' }
            $severityClass = switch ($e.Severity) {
                'SHALL'  { 'sev-shall' }
                'SHOULD' { 'sev-should' }
                default  { 'sev-may' }
            }
            $portalHtml = if ($e.AdminPortal) {
                $url = [System.Web.HttpUtility]::HtmlEncode($e.AdminPortal)
                "<a href=`"$url`" target=`"_blank`" class=`"portal-link`" title=`"Open in admin portal`">&#8599;</a>"
            } else { '' }
            $quotaHtml = if ($e.QuotaNote) {
                $qn = [System.Web.HttpUtility]::HtmlEncode($e.QuotaNote)
                "<span class=`"quota-warn`" title=`"$qn`">&#9888;</span>"
            } else { '' }

            $profileBadges = ''
            foreach ($p in $e.Profiles) {
                $profileBadges += "<span class=`"profile-badge pb-$($p.ToLower())`">$([System.Web.HttpUtility]::HtmlEncode($p))</span>"
            }

            if ($isEdit) {
                $rowsHtml += @"
          <tr class="type-row" data-type="$key" data-workload="$wl">
            <td class="cb-cell"><input type="checkbox" class="type-cb" value="$key"$checkedAttr></td>
            <td class="dn-cell">$dn $quotaHtml $portalHtml</td>
            <td><span class="sev-badge $severityClass">$($e.Severity)</span></td>
            <td class="profiles-cell">$profileBadges</td>
            <td class="desc-cell">$desc</td>
          </tr>

"@
            } else {
                $statusIcon = if ($isMonitored) { '<span class="icon-on">&#10004;</span>' } else { '<span class="icon-off">&#9634;</span>' }
                $rowsHtml += @"
          <tr class="type-row$(if (-not $isMonitored) { ' not-monitored' })" data-type="$key" data-workload="$wl">
            <td class="status-cell">$statusIcon</td>
            <td class="dn-cell">$dn $quotaHtml $portalHtml</td>
            <td><span class="sev-badge $severityClass">$($e.Severity)</span></td>
            <td class="profiles-cell">$profileBadges</td>
            <td class="desc-cell">$desc</td>
          </tr>

"@
            }
        }

        $sectionsHtml += @"
      <div class="workload-section" data-workload="$wl">
        <div class="wl-header" onclick="toggleWorkload('$wl')">
          <span class="wl-arrow" id="arrow-$wl">&#9660;</span>
          <span class="wl-name">$wlDisplay</span>
          <span class="wl-count" id="count-$wl">$monCount / $totalCount</span>
          $(if ($isEdit) { "<button type=`"button`" class=`"btn-sm`" onclick=`"event.stopPropagation(); selectAll('$wl', true)`">All</button><button type=`"button`" class=`"btn-sm`" onclick=`"event.stopPropagation(); selectAll('$wl', false)`">None</button>" })
        </div>
        <table class="type-table" id="table-$wl">
          <thead>
            <tr>
              <th class="col-status">$(if ($isEdit) { '' } else { 'Status' })</th>
              <th class="col-name">Resource Type</th>
              <th class="col-sev">Severity</th>
              <th class="col-profiles">Profiles</th>
              <th class="col-desc">Description</th>
            </tr>
          </thead>
          <tbody>
$rowsHtml
          </tbody>
        </table>
      </div>

"@
    }

    # Profile coverage info banner
    $profileCoverageHtml = ''
    if ($detectedProfileName -and $detectedProfileName -ne 'Full' -and $baselineSet.Count -gt 0) {
        $profileTypeList = switch ($detectedProfileName) {
            'SecurityCritical' { @($profiles.SecurityCritical) }
            'Recommended'      { @($profiles.Recommended) }
        }
        $profileTotal = $profileTypeList.Count
        $baselineHas = @($profileTypeList | Where-Object { $baselineSet.Contains($_) }).Count
        $emptyTypes = $profileTotal - $baselineHas
        $profileCoverageHtml = if ($emptyTypes -gt 0) {
            "<div class='profile-note'>&#9432; Detected profile: <strong>$detectedProfileName</strong> ($profileTotal types). $emptyTypes types currently have no resources in your tenant &mdash; they are still monitored and will appear in drift reports if created.</div>"
        } else {
            "<div class='profile-note profile-note-ok'>&#10004; Profile: <strong>$detectedProfileName</strong> &mdash; all $profileTotal types have resources in baseline.</div>"
        }
    } elseif ($detectedProfileName -eq 'Full') {
        $profileCoverageHtml = "<div class='profile-note'>&#9432; Detected profile: <strong>Full</strong> (all $($Catalog.Count) types).</div>"
    }

    # Profile badge for header
    $profileBadgeHtml = ''
    if ($detectedProfileName) {
        $pbClass = "pb-$($detectedProfileName.ToLower())"
        $profileBadgeHtml = "<span class='header-profile-badge $pbClass'>$([System.Web.HttpUtility]::HtmlEncode($detectedProfileName))</span>"
    }

    # Header title
    $modeLabel = if ($isEdit) { 'Edit Monitor Configuration' } else { 'Monitor Configuration' }
    $headerInfo = if ($MonitorDisplayName) {
        "$([System.Web.HttpUtility]::HtmlEncode($MonitorDisplayName)) &mdash; $ResourceCount resources ($MonitorStatus)"
    } elseif ($ProfileLabel) {
        "Profile: $([System.Web.HttpUtility]::HtmlEncode($ProfileLabel))"
    } else {
        ''
    }

    # Quota card (only if we have a monitor)
    $quotaCard = ''
    if ($MonitoredTypes.Count -gt 0) {
        $quotaCard = @"
    <div class="card quota-card">
      <h3>Quota Estimate</h3>
      <div class="quota-bar-container">
        <div class="quota-bar" id="quotaBar" style="width:0%"></div>
      </div>
      <div class="quota-text" id="quotaText">Calculating...</div>
    </div>
"@
    }

    # Apply buttons (Edit mode only)
    $applySection = ''
    if ($isEdit) {
        $applySection = @"
    <div class="apply-section">
      <button type="button" class="btn btn-primary" id="btnCopy" onclick="copyCommand()">&#128203; Copy PowerShell Command</button>
      <button type="button" class="btn btn-secondary" id="btnDownload" onclick="downloadJson()">&#128190; Download JSON</button>
      <span class="copy-feedback" id="copyFeedback"></span>
    </div>
"@
    }

    # Preset buttons (Edit mode only)
    $presetButtons = ''
    if ($isEdit) {
        $presetButtons = @"
    <div class="preset-bar">
      <span class="preset-label">Presets:</span>
      <button type="button" class="btn-preset pb-securitycritical" onclick="applyPreset('SecurityCritical')">SecurityCritical</button>
      <button type="button" class="btn-preset pb-recommended" onclick="applyPreset('Recommended')">Recommended</button>
      <button type="button" class="btn-preset pb-full" onclick="applyPreset('Full')">Full</button>
      <button type="button" class="btn-preset btn-reset" onclick="resetSelection()">Reset</button>
    </div>
"@
    }

    # Assemble the full HTML
    $monitorIdSafe = [System.Web.HttpUtility]::HtmlEncode($MonitorId)

    # Pre-compute JS-safe values (can't nest complex expressions in here-strings)
    $originalTypesJs = ($MonitoredTypes | ForEach-Object {
        "'$($_.Replace('\', '\\').Replace("'", "\'"))'"
    }) -join ', '
    $isEditJs = $isEdit.ToString().ToLower()
    $totalAvailJs = $Catalog.Count
    $selectedCountJs = $monitoredSet.Count

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>EasyTCM &mdash; $modeLabel</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; background: #f0f2f5; color: #1a1a2e; line-height: 1.6; }
  .container { max-width: 1200px; margin: 0 auto; padding: 2rem 1rem 5rem 1rem; }

  /* Header */
  header { text-align: center; margin-bottom: 1.5rem; }
  header h1 { font-size: 1.8rem; color: #1a1a2e; }
  header h1 span { color: #0078d4; }
  .subtitle { color: #666; font-size: 0.9rem; margin-top: 0.3rem; }
  .header-profile-badge { display: inline-block; padding: 0.2rem 0.7rem; border-radius: 12px; font-size: 0.85rem; font-weight: 700; margin-left: 0.5rem; vertical-align: middle; }
  .profile-note { background: #fff3cd; color: #856404; border: 1px solid #ffc107; border-radius: 8px; padding: 0.6rem 1rem; margin-bottom: 1.2rem; font-size: 0.85rem; }
  .profile-note-ok { background: #d4edda; color: #155724; border-color: #28a745; }
  .profile-match { font-size: 0.8rem; color: #666; margin-top: 0.1rem; }

  /* Preset bar */
  .preset-bar { display: flex; align-items: center; gap: 0.5rem; margin-bottom: 1.2rem; flex-wrap: wrap; }
  .preset-label { font-size: 0.85rem; color: #666; font-weight: 600; }
  .btn-preset { border: 1px solid #ccc; background: white; border-radius: 6px; padding: 0.3rem 0.8rem; font-size: 0.8rem; cursor: pointer; font-weight: 600; transition: all 0.15s; }
  .btn-preset:hover { border-color: #0078d4; color: #0078d4; }
  .btn-reset { border-color: #e74c3c; color: #e74c3c; }
  .btn-reset:hover { background: #fdf2f2; }
  .pb-securitycritical { border-color: #e74c3c; color: #b71c1c; }
  .pb-recommended { border-color: #f39c12; color: #e67e22; }
  .pb-full { border-color: #27ae60; color: #1e8449; }

  /* Cards */
  .card-row { display: flex; gap: 1rem; margin-bottom: 1.2rem; flex-wrap: wrap; }
  .card { background: white; border-radius: 10px; padding: 1rem 1.2rem; box-shadow: 0 1px 3px rgba(0,0,0,0.08); flex: 1; min-width: 200px; }
  .card h3 { font-size: 0.75rem; text-transform: uppercase; color: #888; letter-spacing: 0.05em; margin-bottom: 0.3rem; }
  .card .value { font-size: 1.4rem; font-weight: 700; }
  .card .detail { font-size: 0.8rem; color: #888; margin-top: 0.1rem; }

  /* Quota bar */
  .quota-bar-container { height: 8px; background: #e8e8e8; border-radius: 4px; margin: 0.5rem 0 0.3rem 0; overflow: hidden; }
  .quota-bar { height: 100%; border-radius: 4px; transition: width 0.3s, background 0.3s; background: #27ae60; }

  /* Workload sections */
  .workload-section { margin-bottom: 1rem; }
  .wl-header { display: flex; align-items: center; gap: 0.5rem; padding: 0.6rem 0.8rem; background: #f8f9fa; border-radius: 8px 8px 0 0; cursor: pointer; user-select: none; border: 1px solid #e0e0e0; border-bottom: none; }
  .wl-header:hover { background: #eef1f5; }
  .wl-arrow { font-size: 0.7rem; color: #888; transition: transform 0.2s; }
  .wl-arrow.collapsed { transform: rotate(-90deg); }
  .wl-name { font-weight: 700; font-size: 0.95rem; }
  .wl-count { font-size: 0.8rem; color: #666; margin-left: auto; }
  .btn-sm { border: 1px solid #ccc; background: white; border-radius: 4px; padding: 0.1rem 0.5rem; font-size: 0.7rem; cursor: pointer; margin-left: 0.3rem; }
  .btn-sm:hover { border-color: #0078d4; color: #0078d4; }

  /* Type table */
  .type-table { width: 100%; border-collapse: collapse; background: white; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 8px 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
  .type-table thead th { background: #f8f9fa; text-align: left; padding: 0.5rem 0.8rem; font-size: 0.7rem; text-transform: uppercase; color: #888; letter-spacing: 0.03em; border-bottom: 1px solid #e0e0e0; }
  .type-table tbody td { padding: 0.5rem 0.8rem; border-top: 1px solid #f0f0f0; font-size: 0.85rem; vertical-align: middle; }
  .col-status { width: 40px; text-align: center; }
  .col-name { min-width: 200px; }
  .col-sev { width: 80px; }
  .col-profiles { width: 180px; }
  .col-desc { color: #666; }
  .cb-cell { text-align: center; }
  .cb-cell input { width: 16px; height: 16px; cursor: pointer; }
  .status-cell { text-align: center; }
  .icon-on { color: #27ae60; font-weight: bold; }
  .icon-off { color: #ccc; }
  .not-monitored td { opacity: 0.45; }
  .not-monitored:hover td { opacity: 0.75; }

  /* Severity badges */
  .sev-badge { padding: 0.15rem 0.5rem; border-radius: 10px; font-size: 0.7rem; font-weight: 600; }
  .sev-shall { background: #fde8e8; color: #b71c1c; }
  .sev-should { background: #fef3e0; color: #e65100; }
  .sev-may { background: #e8f5e9; color: #2e7d32; }

  /* Profile badges */
  .profile-badge { padding: 0.1rem 0.4rem; border-radius: 8px; font-size: 0.65rem; font-weight: 600; margin-right: 0.2rem; }
  .pb-securitycritical { background: #fde8e8; color: #b71c1c; }
  .pb-recommended { background: #fef3e0; color: #e65100; }
  .pb-full { background: #e8f5e9; color: #2e7d32; }

  /* Portal link & quota warning */
  .portal-link { color: #0078d4; text-decoration: none; font-weight: 600; margin-left: 0.3rem; }
  .portal-link:hover { text-decoration: underline; }
  .quota-warn { color: #f39c12; margin-left: 0.3rem; cursor: help; }

  /* Apply section — sticky at bottom */
  .apply-section { display: flex; align-items: center; gap: 0.8rem; padding: 0.8rem 1.2rem; background: white; border-top: 2px solid #0078d4; box-shadow: 0 -2px 8px rgba(0,0,0,0.1); flex-wrap: wrap; position: sticky; bottom: 0; z-index: 100; }
  .btn { border: none; border-radius: 8px; padding: 0.6rem 1.2rem; font-size: 0.9rem; font-weight: 600; cursor: pointer; transition: all 0.15s; }
  .btn-primary { background: #0078d4; color: white; }
  .btn-primary:hover { background: #005a9e; }
  .btn-secondary { background: #f0f2f5; color: #333; border: 1px solid #ccc; }
  .btn-secondary:hover { background: #e0e2e5; }
  .copy-feedback { font-size: 0.85rem; color: #27ae60; font-weight: 600; opacity: 0; transition: opacity 0.3s; }

  /* Footer */
  footer { text-align: center; color: #999; font-size: 0.8rem; margin-top: 2rem; padding-top: 1rem; border-top: 1px solid #ddd; }
  footer a { color: #0078d4; text-decoration: none; }

  @media (max-width: 768px) {
    .card-row { flex-direction: column; }
    .col-profiles, .col-desc { display: none; }
    .preset-bar { justify-content: center; }
  }
</style>
</head>
<body>
<div class="container">
  <header>
    <h1>&#128737; <span>EasyTCM</span> $modeLabel $profileBadgeHtml</h1>
    <div class="subtitle">$headerInfo &mdash; $timestamp UTC</div>
    <div class="profile-match" id="profileMatch"></div>
  </header>

$profileCoverageHtml

$presetButtons

  <div class="card-row">
    <div class="card">
      <h3>Selected Types</h3>
      <div class="value" id="selectedCount">$selectedCountJs</div>
      <div class="detail">of $totalAvailJs available</div>
    </div>
    <div class="card">
      <h3>Workloads</h3>
      <div class="value">$($workloadOrder.Count)</div>
      <div class="detail">Entra, Exchange, Teams, Intune, S&amp;C</div>
    </div>
$quotaCard
  </div>

$sectionsHtml

$applySection

  <footer>
    Generated by <a href="https://github.com/kayasax/EasyTCM">EasyTCM</a> &mdash; Tenant Change Management for Microsoft 365
  </footer>
</div>

<script>
(function() {
  // Data
  const monitorId = '$monitorIdSafe';
  const profiles = $profileJson;
  const originalTypes = new Set([$originalTypesJs]);
  const isEdit = $isEditJs;
  const totalAvail = $totalAvailJs;

  // Toggle workload section
  window.toggleWorkload = function(wl) {
    const table = document.getElementById('table-' + wl);
    const arrow = document.getElementById('arrow-' + wl);
    if (table.style.display === 'none') {
      table.style.display = '';
      arrow.classList.remove('collapsed');
    } else {
      table.style.display = 'none';
      arrow.classList.add('collapsed');
    }
  };

  // Select all/none in a workload
  window.selectAll = function(wl, checked) {
    document.querySelectorAll('.type-row[data-workload="' + wl + '"] .type-cb').forEach(function(cb) {
      cb.checked = checked;
    });
    updateCounts();
  };

  // Apply preset
  window.applyPreset = function(name) {
    const types = new Set((profiles[name] || []).map(function(t) { return t.toLowerCase(); }));
    document.querySelectorAll('.type-cb').forEach(function(cb) {
      cb.checked = types.has(cb.value.toLowerCase());
    });
    updateCounts();
  };

  // Reset to original selection
  window.resetSelection = function() {
    document.querySelectorAll('.type-cb').forEach(function(cb) {
      cb.checked = originalTypes.has(cb.value);
    });
    updateCounts();
  };

  // Update counts and quota
  function updateCounts() {
    const checked = document.querySelectorAll('.type-cb:checked');
    const selectedEl = document.getElementById('selectedCount');
    if (selectedEl) selectedEl.textContent = checked.length;

    // Update workload counts
    ['Entra', 'Exchange', 'Teams', 'Intune', 'SecurityAndCompliance'].forEach(function(wl) {
      const total = document.querySelectorAll('.type-row[data-workload="' + wl + '"] .type-cb').length;
      const sel = document.querySelectorAll('.type-row[data-workload="' + wl + '"] .type-cb:checked').length;
      const countEl = document.getElementById('count-' + wl);
      if (countEl) countEl.textContent = sel + ' / ' + total;
    });

    // Quota estimate (rough: ~3 resources per type average)
    const estResources = checked.length * 3;
    const quotaBar = document.getElementById('quotaBar');
    const quotaText = document.getElementById('quotaText');
    if (quotaBar && quotaText) {
      const pct = Math.min(Math.round((estResources / 200) * 100), 100);
      quotaBar.style.width = pct + '%';
      quotaBar.style.background = pct > 80 ? '#e74c3c' : pct > 50 ? '#f39c12' : '#27ae60';
      quotaText.textContent = '~' + estResources + ' / 200 resources per run (' + pct + '%)';
    }

    // Profile match detection
    var matchEl = document.getElementById('profileMatch');
    if (matchEl && isEdit) {
      var selected = new Set();
      document.querySelectorAll('.type-cb:checked').forEach(function(cb) { selected.add(cb.value.toLowerCase()); });
      var matchName = '';
      ['SecurityCritical', 'Recommended', 'Full'].forEach(function(name) {
        var pTypes = new Set((profiles[name] || []).map(function(t) { return t.toLowerCase(); }));
        if (pTypes.size === selected.size) {
          var match = true;
          pTypes.forEach(function(t) { if (!selected.has(t)) match = false; });
          if (match) matchName = name;
        }
      });
      if (matchName) {
        matchEl.textContent = 'Current selection matches: ' + matchName + ' profile';
        matchEl.style.color = '#27ae60';
      } else {
        matchEl.textContent = 'Custom selection (does not match any preset profile)';
        matchEl.style.color = '#888';
      }
    }
  }

  // Copy PowerShell command
  window.copyCommand = function() {
    const selected = [];
    document.querySelectorAll('.type-cb:checked').forEach(function(cb) {
      selected.push("    '" + cb.value + "'");
    });
    const ts = new Date().toISOString().replace(/\.\d{3}Z/, 'Z');
    let cmd = '# EasyTCM Monitor Update \u2014 ' + ts + '\n';
    cmd += '# ' + selected.length + ' types selected\n';
    cmd += 'Edit-TCMMonitor' + (monitorId ? " -MonitorId '" + monitorId + "'" : '') + ' -ResourceTypes @(\n';
    cmd += selected.join('\n') + '\n';
    cmd += ')';

    navigator.clipboard.writeText(cmd).then(function() {
      const fb = document.getElementById('copyFeedback');
      if (fb) {
        fb.textContent = '\u2714 Copied! Paste into your PowerShell terminal.';
        fb.style.opacity = '1';
        setTimeout(function() { fb.style.opacity = '0'; }, 3000);
      }
    }).catch(function() {
      // Fallback: select a textarea
      const ta = document.createElement('textarea');
      ta.value = cmd;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
      const fb = document.getElementById('copyFeedback');
      if (fb) {
        fb.textContent = '\u2714 Copied!';
        fb.style.opacity = '1';
        setTimeout(function() { fb.style.opacity = '0'; }, 3000);
      }
    });
  };

  // Download JSON
  window.downloadJson = function() {
    const selected = [];
    document.querySelectorAll('.type-cb:checked').forEach(function(cb) {
      selected.push(cb.value);
    });
    const data = {
      monitorId: monitorId || null,
      generatedAt: new Date().toISOString(),
      resourceTypes: selected
    };
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'easytcm-monitor-selection.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  // Wire up checkboxes for live updates
  if (isEdit) {
    document.querySelectorAll('.type-cb').forEach(function(cb) {
      cb.addEventListener('change', updateCounts);
    });
  }

  // Initial count
  updateCounts();
})();
</script>
</body>
</html>
"@

    return $html
}
