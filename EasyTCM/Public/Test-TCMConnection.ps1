function Test-TCMConnection {
    <#
    .SYNOPSIS
        Verify that the current Graph connection can reach the TCM API.
    .PARAMETER Quiet
        Return $true/$false instead of a detailed object.
    .EXAMPLE
        Test-TCMConnection
    #>
    [CmdletBinding()]
    param(
        [switch]$Quiet
    )

    $result = [PSCustomObject]@{
        GraphConnected    = $false
        TCMApiReachable   = $false
        ServicePrincipal  = $null
        MonitorCount      = 0
    }

    # Check Graph connection
    try {
        $context = Get-MgContext
        if (-not $context) {
            if ($Quiet) { return $false }
            Write-Warning 'Not connected to Microsoft Graph. Run Connect-MgGraph first.'
            return $result
        }
        $result.GraphConnected = $true
    }
    catch {
        if ($Quiet) { return $false }
        Write-Warning "Graph connection check failed: $_"
        return $result
    }

    # Check TCM SP exists
    try {
        $sp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$script:TCM_APP_ID'" -ErrorAction Stop
        if ($sp.value -and $sp.value.Count -gt 0) {
            $result.ServicePrincipal = $sp.value[0].id
        }
    }
    catch {
        Write-Verbose "TCM SP lookup failed: $_"
    }

    # Check TCM API reachability
    try {
        $monitors = Invoke-TCMGraphRequest -Endpoint 'configurationMonitors?$top=1' -ErrorAction Stop
        $result.TCMApiReachable = $true
        if ($monitors -is [System.Collections.IList]) {
            $result.MonitorCount = $monitors.Count
        }
    }
    catch {
        Write-Verbose "TCM API check failed: $_"
    }

    if ($Quiet) {
        return $result.TCMApiReachable
    }

    $result
}
