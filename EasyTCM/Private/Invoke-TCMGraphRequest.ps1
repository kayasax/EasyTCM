function Invoke-TCMGraphRequest {
    <#
    .SYNOPSIS
        Internal helper to call TCM Graph API endpoints.
    .DESCRIPTION
        Wraps Invoke-MgGraphRequest with TCM base URL, error handling, and pagination support.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Endpoint,

        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',

        [object]$Body,

        [switch]$All
    )

    $uri = "$script:TCM_BASE_URL/$Endpoint"

    $params = @{
        Method = $Method
        Uri    = $uri
    }

    if ($Body) {
        $params['Body']        = $Body | ConvertTo-Json -Depth 20
        $params['ContentType'] = 'application/json'
    }

    try {
        $response = Invoke-MgGraphRequest @params

        if ($Method -eq 'DELETE') {
            return
        }

        # Handle collections with pagination
        if ($response.value) {
            $results = [System.Collections.Generic.List[object]]::new()
            $results.AddRange([object[]]$response.value)

            if ($All) {
                while ($response.'@odata.nextLink') {
                    $response = Invoke-MgGraphRequest -Method GET -Uri $response.'@odata.nextLink'
                    if ($response.value) {
                        $results.AddRange([object[]]$response.value)
                    }
                }
            }

            return $results
        }

        return $response
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode
        $errorBody  = $_.ErrorDetails.Message

        if ($errorBody) {
            try {
                $parsed  = $errorBody | ConvertFrom-Json
                $message = $parsed.error.message
            }
            catch {
                $message = $errorBody
            }
        }
        else {
            $message = $_.Exception.Message
        }

        Write-Error "TCM API error [$Method $Endpoint] ($statusCode): $message"
    }
}
