function Get-TCMDrift {
    <#
    .SYNOPSIS
        Retrieve active configuration drifts detected by TCM monitors.
    .DESCRIPTION
        Returns drifts with enriched information: workload classification,
        property-level details (expected vs actual), and severity hints.
    .PARAMETER MonitorId
        Filter drifts by a specific monitor.
    .PARAMETER Status
        Filter by drift status. Default: active.
    .PARAMETER Workload
        Filter by workload (Entra, Exchange, etc.).
    .EXAMPLE
        Get-TCMDrift
    .EXAMPLE
        Get-TCMDrift -MonitorId 'b166c9cb-...' -Status active
    .EXAMPLE
        Get-TCMDrift -Workload Exchange | Format-Table
    #>
    [CmdletBinding()]
    param(
        [string]$MonitorId,

        [ValidateSet('active', 'fixed', 'all')]
        [string]$Status = 'active',

        [ValidateSet('Entra', 'Exchange', 'Intune', 'Teams', 'SecurityAndCompliance')]
        [string]$Workload
    )

    $filter = @()
    if ($MonitorId) { $filter += "monitorId eq '$MonitorId'" }
    if ($Status -ne 'all') { $filter += "status eq '$Status'" }

    $endpoint = 'configurationDrifts'
    if ($filter.Count -gt 0) {
        $endpoint += '?$filter=' + ($filter -join ' and ')
    }

    $drifts = Invoke-TCMGraphRequest -Endpoint $endpoint -All

    if (-not $drifts) {
        Write-Host 'No drifts found.' -ForegroundColor Green
        return @()
    }

    # Enrich with workload classification
    $workloadMap = Get-TCMWorkloadResources
    $enriched = foreach ($drift in $drifts) {
        $detectedWorkload = 'Unknown'
        foreach ($wl in $workloadMap.Keys) {
            if ($workloadMap[$wl] | Where-Object { $drift.resourceType -like "$_*" -or $drift.resourceType -eq $_ }) {
                $detectedWorkload = $wl
                break
            }
        }

        # Also try prefix matching
        if ($detectedWorkload -eq 'Unknown') {
            $prefix = ($drift.resourceType -split '\.')[1]
            if ($prefix) {
                $match = $workloadMap.Keys | Where-Object { $_.ToLower() -eq $prefix.ToLower() }
                if ($match) { $detectedWorkload = $match }
            }
        }

        [PSCustomObject]@{
            Id                    = $drift.id
            MonitorId             = $drift.monitorId
            Workload              = $detectedWorkload
            ResourceType          = $drift.resourceType
            ResourceDisplay       = $drift.baselineResourceDisplayName
            ResourceIdentifier    = $drift.resourceInstanceIdentifier
            Status                = $drift.status
            FirstReported         = $drift.firstReportedDateTime
            DriftedPropertyCount  = ($drift.driftedProperties | Measure-Object).Count
            DriftedProperties     = $drift.driftedProperties
        }
    }

    if ($Workload) {
        $enriched = $enriched | Where-Object { $_.Workload -eq $Workload }
    }

    $enriched
}
