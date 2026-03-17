function ConvertTo-TCMBaseline {
    <#
    .SYNOPSIS
        Convert a TCM snapshot into a monitor baseline — the killer feature.
    .DESCRIPTION
        Takes a completed snapshot's content and transforms it into the baseline
        format expected by New-TCMMonitor. This is the bridge between "what is my
        current config" and "monitor it for drift".

        Workflow:
        1. New-TCMSnapshot -Wait   → get current config
        2. ConvertTo-TCMBaseline   → turn it into a baseline
        3. New-TCMMonitor          → start monitoring
    .PARAMETER SnapshotContent
        The snapshot content object (from Get-TCMSnapshot -IncludeContent).
    .PARAMETER SnapshotId
        Alternatively, provide a snapshot job ID and the content will be fetched.
    .PARAMETER DisplayName
        Name for the generated baseline. Defaults to "Baseline from snapshot".
    .PARAMETER Description
        Optional description for the baseline.
    .PARAMETER ExcludeResources
        Resource type names to exclude from the baseline.
    .EXAMPLE
        $snapshot = New-TCMSnapshot -DisplayName "Current" -Workloads Entra -Wait
        $snapshot | ConvertTo-TCMBaseline | New-TCMMonitor -Name "Entra Monitor"
    .EXAMPLE
        ConvertTo-TCMBaseline -SnapshotId 'c91a1470-...' -ExcludeResources 'microsoft.entra.administrativeunit'
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ParameterSetName = 'Content')]
        [object]$SnapshotContent,

        [Parameter(ParameterSetName = 'Id')]
        [string]$SnapshotId,

        [string]$DisplayName = 'Baseline from snapshot',

        [string]$Description,

        [string[]]$ExcludeResources
    )

    process {
        # Resolve content
        if ($SnapshotId) {
            $job = Get-TCMSnapshot -Id $SnapshotId -IncludeContent
            if ($job.status -ne 'succeeded' -and $job.status -ne 'partiallySuccessful') {
                throw "Snapshot '$SnapshotId' is not complete (status: $($job.status)). Wait for it to finish."
            }
            $SnapshotContent = $job.snapshotContent
        }

        if (-not $SnapshotContent) {
            throw 'No snapshot content provided. Use -SnapshotId or pipe a snapshot with content.'
        }

        # The snapshot content contains resource instances grouped by type.
        # We need to transform each into a baseline resource entry.
        $baselineResources = [System.Collections.Generic.List[object]]::new()

        # Handle both array and object formats
        $items = if ($SnapshotContent -is [System.Collections.IList]) {
            $SnapshotContent
        }
        elseif ($SnapshotContent.resources) {
            $SnapshotContent.resources
        }
        elseif ($SnapshotContent.value) {
            $SnapshotContent.value
        }
        else {
            Write-Warning 'Unexpected snapshot content format. Attempting direct conversion.'
            @($SnapshotContent)
        }

        foreach ($item in $items) {
            $resourceType = $item.resourceType

            if ($ExcludeResources -and $resourceType -in $ExcludeResources) {
                Write-Verbose "Excluding resource type: $resourceType"
                continue
            }

            # Build a baseline resource from the snapshot data
            $baselineResource = @{
                resourceType = $resourceType
                displayName  = $item.displayName ?? "$resourceType instance"
                properties   = @{}
            }

            # Copy all configuration properties (exclude metadata)
            $metadataKeys = @('@odata.type', 'id', 'resourceType', 'displayName', 'description')
            $props = if ($item.properties) { $item.properties } else { $item }

            foreach ($key in $props.Keys) {
                if ($key -notin $metadataKeys) {
                    $baselineResource.properties[$key] = $props[$key]
                }
            }

            if ($baselineResource.properties.Count -gt 0) {
                $baselineResources.Add($baselineResource)
            }
        }

        Write-Host "Converted $($baselineResources.Count) resources into baseline." -ForegroundColor Cyan

        $baseline = @{
            displayName = $DisplayName
            resources   = $baselineResources
        }
        if ($Description) { $baseline.description = $Description }

        $baseline
    }
}
