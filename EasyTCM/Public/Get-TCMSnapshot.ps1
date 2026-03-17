function Get-TCMSnapshot {
    <#
    .SYNOPSIS
        Retrieve snapshot job details and results.
    .PARAMETER Id
        The snapshot job ID. If omitted, lists all snapshot jobs.
    .PARAMETER IncludeContent
        Download and return the snapshot content (the extracted configuration).
    .EXAMPLE
        Get-TCMSnapshot
    .EXAMPLE
        Get-TCMSnapshot -Id 'c91a1470-acc9-4585-bc03-522ae898f82f' -IncludeContent
    #>
    [CmdletBinding()]
    param(
        [string]$Id,
        [switch]$IncludeContent
    )

    if ($Id) {
        $job = Invoke-TCMGraphRequest -Endpoint "configurationSnapshotJobs/$Id"

        $resLocation = if ($job -is [System.Collections.IDictionary]) { $job['resourceLocation'] } else { $job.resourceLocation }

        if ($IncludeContent -and $resLocation) {
            try {
                $content = Invoke-MgGraphRequest -Method GET -Uri $resLocation
                if ($job -is [System.Collections.IDictionary]) {
                    $job['snapshotContent'] = $content
                }
                else {
                    $job | Add-Member -NotePropertyName 'snapshotContent' -NotePropertyValue $content -Force
                }
            }
            catch {
                Write-Warning "Could not download snapshot content: $_"
            }
        }

        return $job
    }

    Invoke-TCMGraphRequest -Endpoint 'configurationSnapshotJobs' -All
}
