function Update-TCMMonitor {
    <#
    .SYNOPSIS
        Update a monitor's baseline, name, or description.
    .DESCRIPTION
        WARNING: Updating a monitor's baseline deletes ALL previously generated
        monitoring results and detected drifts for that monitor.
    .PARAMETER Id
        The monitor ID to update.
    .PARAMETER DisplayName
        New display name.
    .PARAMETER Description
        New description.
    .PARAMETER Baseline
        New baseline. WARNING: this deletes all existing drifts for this monitor.
    .EXAMPLE
        Update-TCMMonitor -Id $monitorId -DisplayName "Renamed Monitor"
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Id,

        [string]$DisplayName,
        [string]$Description,
        [hashtable]$Baseline
    )

    $body = @{}
    if ($DisplayName)  { $body.displayName = $DisplayName }
    if ($Description)  { $body.description = $Description }

    if ($Baseline) {
        if (-not $PSCmdlet.ShouldProcess("Monitor $Id", 'Update baseline (THIS DELETES ALL EXISTING DRIFTS)')) {
            return
        }
        $body.baseline = $Baseline
    }
    elseif ($body.Count -gt 0) {
        if (-not $PSCmdlet.ShouldProcess("Monitor $Id", 'Update')) {
            return
        }
    }
    else {
        Write-Warning 'No properties specified to update.'
        return
    }

    $result = Invoke-TCMGraphRequest -Endpoint "configurationMonitors/$Id" -Method PATCH -Body $body
    Write-Host "Monitor '$Id' updated." -ForegroundColor Green
    if ($Baseline) {
        Write-Warning 'Baseline was updated — all previous drifts and monitoring results for this monitor have been deleted.'
    }
    $result
}
