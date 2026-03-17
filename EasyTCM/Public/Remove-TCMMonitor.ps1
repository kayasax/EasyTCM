function Remove-TCMMonitor {
    <#
    .SYNOPSIS
        Delete a TCM monitor.
    .PARAMETER Id
        The monitor ID to delete.
    .EXAMPLE
        Remove-TCMMonitor -Id 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    if ($PSCmdlet.ShouldProcess("Monitor $Id", 'Delete')) {
        Invoke-TCMGraphRequest -Endpoint "configurationMonitors/$Id" -Method DELETE
        Write-Host "Monitor '$Id' deleted." -ForegroundColor Green
    }
}
