function Get-TCMMonitor {
    <#
    .SYNOPSIS
        List or retrieve TCM monitors with baseline summary.
    .DESCRIPTION
        Returns monitors enriched with baseline metadata: resource count, workload
        breakdown, and monitored resource types. This answers "what am I monitoring?"
        at a glance.

        Use -IncludeBaseline to also attach the full raw baseline (resource instances
        with all properties).
    .PARAMETER Id
        Get a specific monitor by ID. If omitted, lists all monitors.
    .PARAMETER IncludeBaseline
        Include the full baseline details (resource instances + properties) in the response.
    .PARAMETER SkipBaseline
        Skip baseline fetch entirely — returns raw API output only. Faster, but no summary.
    .EXAMPLE
        Get-TCMMonitor
        # Shows: DisplayName, Status, ResourceCount, WorkloadSummary, Id
    .EXAMPLE
        Get-TCMMonitor -Id $id
        # Detailed view with monitored resource types
    .EXAMPLE
        Get-TCMMonitor -Id $id -IncludeBaseline
        # Includes full raw baseline in the Baseline property
    #>
    [CmdletBinding()]
    param(
        [string]$Id,
        [switch]$IncludeBaseline,
        [switch]$SkipBaseline
    )

    if ($Id) {
        $monitor = Invoke-TCMGraphRequest -Endpoint "configurationMonitors/$Id"
        if (-not $SkipBaseline) {
            $monitor = Add-TCMMonitorSummary -Monitor $monitor -IncludeBaseline:$IncludeBaseline
        }
        return $monitor
    }

    $monitors = Invoke-TCMGraphRequest -Endpoint 'configurationMonitors' -All

    if ($SkipBaseline) { return $monitors }

    foreach ($m in $monitors) {
        Add-TCMMonitorSummary -Monitor $m -IncludeBaseline:$IncludeBaseline
    }
}

function Add-TCMMonitorSummary {
    <# .SYNOPSIS Internal: enriches a monitor with baseline summary. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Monitor,
        [switch]$IncludeBaseline
    )

    $monitorId = if ($Monitor -is [System.Collections.IDictionary]) { $Monitor['id'] } else { $Monitor.id }
    $baseline = $null
    try {
        $baseline = Invoke-TCMGraphRequest -Endpoint "configurationMonitors/$monitorId/baseline"
    }
    catch {
        Write-Warning "Could not retrieve baseline for monitor $monitorId"
    }

    # Build summary from baseline resources
    $resourceCount = 0
    $workloadSummary = ''
    $monitoredTypes = @()

    if ($baseline) {
        $resources = if ($baseline -is [System.Collections.IDictionary]) { $baseline['resources'] } else { $baseline.resources }
        if ($resources) {
            $resourceCount = @($resources).Count

            # Group by workload (second segment of resource type)
            $groups = @($resources) | Group-Object {
                $rt = if ($_ -is [System.Collections.IDictionary]) { $_['resourceType'] } else { $_.resourceType }
                $parts = $rt -split '\.'
                if ($parts.Count -ge 2) { $parts[1].Substring(0,1).ToUpper() + $parts[1].Substring(1) } else { 'Unknown' }
            } | Sort-Object Name
            $workloadSummary = ($groups | ForEach-Object { "$($_.Name)($($_.Count))" }) -join ', '

            # Distinct resource types
            $monitoredTypes = @($resources | ForEach-Object {
                if ($_ -is [System.Collections.IDictionary]) { $_['resourceType'] } else { $_.resourceType }
            } | Sort-Object -Unique)
        }
    }

    # Build a PSCustomObject for clean output
    $displayName = if ($Monitor -is [System.Collections.IDictionary]) { $Monitor['displayName'] } else { $Monitor.displayName }
    $status      = if ($Monitor -is [System.Collections.IDictionary]) { $Monitor['status'] } else { $Monitor.status }
    $frequency   = if ($Monitor -is [System.Collections.IDictionary]) { $Monitor['monitorRunFrequencyInHours'] } else { $Monitor.monitorRunFrequencyInHours }
    $created     = if ($Monitor -is [System.Collections.IDictionary]) { $Monitor['createdDateTime'] } else { $Monitor.createdDateTime }
    $description = if ($Monitor -is [System.Collections.IDictionary]) { $Monitor['description'] } else { $Monitor.description }

    $result = [PSCustomObject]@{
        PSTypeName       = 'EasyTCM.Monitor'
        DisplayName      = $displayName
        Status           = $status
        ResourceCount    = $resourceCount
        WorkloadSummary  = $workloadSummary
        MonitoredTypes   = $monitoredTypes
        Frequency        = "${frequency}h"
        Id               = $monitorId
        Description      = $description
        CreatedDateTime  = $created
    }

    if ($IncludeBaseline -and $baseline) {
        $result | Add-Member -NotePropertyName 'Baseline' -NotePropertyValue $baseline -Force
    }

    # Set default display properties for table view
    $defaultProps = [System.Management.Automation.PSPropertySet]::new(
        'DefaultDisplayPropertySet',
        [string[]]@('DisplayName', 'Status', 'ResourceCount', 'WorkloadSummary', 'Frequency', 'Id')
    )
    $result | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value ([System.Management.Automation.PSMemberInfo[]]@($defaultProps)) -Force

    $result
}
