function Get-TCMMonitor {
    <#
    .SYNOPSIS
        List or retrieve TCM monitors.
    .PARAMETER Id
        Get a specific monitor by ID. If omitted, lists all monitors.
    .PARAMETER IncludeBaseline
        Include the baseline details in the response.
    .EXAMPLE
        Get-TCMMonitor
    .EXAMPLE
        Get-TCMMonitor -Id 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02' -IncludeBaseline
    #>
    [CmdletBinding()]
    param(
        [string]$Id,
        [switch]$IncludeBaseline
    )

    if ($Id) {
        $monitor = Invoke-TCMGraphRequest -Endpoint "configurationMonitors/$Id"

        if ($IncludeBaseline) {
            try {
                $baseline = Invoke-TCMGraphRequest -Endpoint "configurationMonitors/$Id/baseline"
                $monitor | Add-Member -NotePropertyName 'baseline' -NotePropertyValue $baseline -Force
            }
            catch {
                Write-Warning "Could not retrieve baseline for monitor $Id"
            }
        }

        return $monitor
    }

    Invoke-TCMGraphRequest -Endpoint 'configurationMonitors' -All
}
