function Remove-TCMSnapshot {
    <#
    .SYNOPSIS
        Delete a snapshot job.
    .PARAMETER Id
        The snapshot job ID to delete.
    .EXAMPLE
        Remove-TCMSnapshot -Id 'c91a1470-acc9-4585-bc03-522ae898f82f'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    if ($PSCmdlet.ShouldProcess("Snapshot $Id", 'Delete')) {
        Invoke-TCMGraphRequest -Endpoint "configurationSnapshotJobs/$Id" -Method DELETE
        Write-Host "Snapshot job '$Id' deleted." -ForegroundColor Green
    }
}
