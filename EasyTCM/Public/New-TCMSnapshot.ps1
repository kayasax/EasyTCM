function New-TCMSnapshot {
    <#
    .SYNOPSIS
        Create a snapshot of the current tenant configuration for one or more workloads.
    .DESCRIPTION
        Initiates an asynchronous snapshot job via the TCM API. The snapshot extracts
        the current configuration for the specified resource types. Use Get-TCMSnapshot
        to check status and retrieve results.
    .PARAMETER DisplayName
        A friendly name for the snapshot job.
    .PARAMETER Description
        Optional description.
    .PARAMETER Resources
        Specific TCM resource type names (e.g., 'microsoft.exchange.transportrule').
    .PARAMETER Workloads
        Shortcut: specify workload names and all their resource types will be included.
    .PARAMETER Wait
        Wait for the snapshot job to complete before returning.
    .PARAMETER TimeoutSeconds
        Maximum wait time when -Wait is specified. Default: 300.
    .EXAMPLE
        New-TCMSnapshot -DisplayName "Pre-change baseline" -Workloads Entra, Exchange
    .EXAMPLE
        New-TCMSnapshot -DisplayName "CA Policies" -Resources 'microsoft.entra.conditionalaccesspolicy' -Wait
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName,

        [string]$Description,

        [string[]]$Resources,

        [ValidateSet('Entra', 'Exchange', 'Intune', 'Teams', 'Defender', 'Purview')]
        [string[]]$Workloads,

        [switch]$Wait,

        [int]$TimeoutSeconds = 300
    )

    if (-not $Resources -and -not $Workloads) {
        throw 'Specify either -Resources or -Workloads.'
    }

    # Resolve workloads to resource names
    if ($Workloads) {
        $map = Get-TCMWorkloadResources
        $resolved = $Workloads | ForEach-Object { $map[$_] } | Where-Object { $_ }
        $Resources = @($Resources) + @($resolved) | Select-Object -Unique
    }

    $body = @{
        displayName = $DisplayName
        resources   = @($Resources)
    }
    if ($Description) { $body.description = $Description }

    Write-Host "Creating snapshot '$DisplayName' with $($Resources.Count) resource types..." -ForegroundColor Cyan
    $job = Invoke-TCMGraphRequest -Endpoint 'configurationSnapshots/createSnapshot' -Method POST -Body $body

    if (-not $Wait) {
        Write-Host "Snapshot job created (Id: $($job.id), Status: $($job.status))" -ForegroundColor Green
        Write-Host "Use Get-TCMSnapshot -Id '$($job.id)' to check progress." -ForegroundColor DarkGray
        return $job
    }

    # Poll until complete
    $elapsed = 0
    $interval = 10
    while ($job.status -in @('notStarted', 'running') -and $elapsed -lt $TimeoutSeconds) {
        Write-Host "  Status: $($job.status) — waiting ${interval}s..." -ForegroundColor DarkGray
        Start-Sleep -Seconds $interval
        $elapsed += $interval
        $job = Invoke-TCMGraphRequest -Endpoint "configurationSnapshotJobs/$($job.id)"
    }

    if ($job.status -eq 'succeeded') {
        Write-Host "Snapshot completed successfully." -ForegroundColor Green
    }
    elseif ($job.status -eq 'partiallySuccessful') {
        Write-Warning "Snapshot partially successful. Some resources may have errors."
    }
    else {
        Write-Warning "Snapshot status: $($job.status). Errors: $($job.errorDetails -join '; ')"
    }

    $job
}
