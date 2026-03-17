function Get-TCMMonitoringResult {
    <#
    .SYNOPSIS
        Get monitoring results for a specific monitor.
    .PARAMETER MonitorId
        The monitor ID to get results for.
    .EXAMPLE
        Get-TCMMonitoringResult -MonitorId 'bf77ee1e-...'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$MonitorId
    )

    Invoke-TCMGraphRequest -Endpoint "configurationMonitors/$MonitorId/results" -All
}
