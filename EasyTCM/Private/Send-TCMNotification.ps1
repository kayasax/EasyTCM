function Send-TCMNotification {
    <#
    .SYNOPSIS
        Send drift notification to Teams via incoming webhook.
    .DESCRIPTION
        Internal helper. Posts an Adaptive Card to a Teams channel webhook
        with drift summary, monitor metadata, and admin portal links.
    .PARAMETER Drifts
        Array of drift objects from Get-TCMDrift.
    .PARAMETER Monitor
        Monitor object from Get-TCMMonitor.
    .PARAMETER WebhookUrl
        Teams incoming webhook URL.
    .PARAMETER CompareResult
        Optional Compare-TCMBaseline result for new/deleted resource counts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Drifts,

        [Parameter(Mandatory)]
        [PSObject]$Monitor,

        [Parameter(Mandatory)]
        [string]$WebhookUrl,

        [PSObject]$CompareResult
    )

    # ── Build facts ─────────────────────────────────────────────────
    $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm') + ' UTC'
    $driftCount = $Drifts.Count
    $newCount = if ($CompareResult) { $CompareResult.NewCount } else { 0 }
    $deletedCount = if ($CompareResult) { $CompareResult.DeletedCount } else { 0 }

    # Determine card theme
    if ($driftCount -gt 0) {
        $statusIcon = '⚠️'
        $statusText = "$driftCount configuration drift(s) detected"
        $accentColor = 'attention'
    }
    elseif ($newCount -gt 0 -or $deletedCount -gt 0) {
        $statusIcon = '🔶'
        $statusText = "$newCount new, $deletedCount deleted untracked resource(s)"
        $accentColor = 'warning'
    }
    else {
        $statusIcon = '✅'
        $statusText = 'No drift — configuration matches baseline'
        $accentColor = 'good'
    }

    # ── Build drift detail blocks ───────────────────────────────────
    $driftBlocks = @()

    if ($driftCount -gt 0) {
        $grouped = $Drifts | Group-Object -Property ResourceType
        foreach ($group in $grouped) {
            $shortType = ($group.Name -split '\.')[-1]
            $lines = @()
            foreach ($d in $group.Group | Select-Object -First 5) {
                $propSummary = ($d.DriftedProperties | Select-Object -First 3 | ForEach-Object {
                    "$($_.propertyName): ``$($_.baselineValue)`` → ``$($_.currentValue)``"
                }) -join '\n'
                $lines += "- **$($d.ResourceDisplay)** — $($d.DriftedPropertyCount) changed"
                if ($propSummary) { $lines += "  $propSummary" }
            }
            if ($group.Count -gt 5) {
                $lines += "- *... and $($group.Count - 5) more*"
            }

            $driftBlocks += @{
                type = 'TextBlock'
                text = "**$shortType** ($($group.Count))"
                weight = 'Bolder'
                spacing = 'Medium'
            }
            $driftBlocks += @{
                type = 'TextBlock'
                text = ($lines -join '\n')
                wrap = $true
                spacing = 'Small'
            }
        }
    }

    # ── Baseline comparison block ───────────────────────────────────
    if ($CompareResult -and ($newCount -gt 0 -or $deletedCount -gt 0)) {
        $driftBlocks += @{
            type = 'TextBlock'
            text = "**Untracked resources:** $newCount new, $deletedCount deleted"
            weight = 'Bolder'
            spacing = 'Medium'
            color = 'warning'
        }
    }

    # ── Assemble Adaptive Card ──────────────────────────────────────
    $cardBody = @(
        @{
            type = 'TextBlock'
            size = 'Medium'
            weight = 'Bolder'
            text = "$statusIcon EasyTCM — $statusText"
            wrap = $true
            color = $accentColor
        }
        @{
            type = 'FactSet'
            facts = @(
                @{ title = 'Monitor'; value = $Monitor.DisplayName }
                @{ title = 'Resources'; value = "$($Monitor.ResourceCount) monitored" }
                @{ title = 'Checked'; value = $timestamp }
            )
        }
    )
    $cardBody += $driftBlocks

    # Action buttons
    $actions = @(
        @{
            type = 'Action.OpenUrl'
            title = 'Entra Portal'
            url = 'https://entra.microsoft.com'
        }
        @{
            type = 'Action.OpenUrl'
            title = 'Exchange Admin'
            url = 'https://admin.exchange.microsoft.com'
        }
    )

    $card = @{
        type = 'message'
        attachments = @(
            @{
                contentType = 'application/vnd.microsoft.card.adaptive'
                contentUrl = $null
                content = @{
                    '$schema' = 'http://adaptivecards.io/schemas/adaptive-card.json'
                    type = 'AdaptiveCard'
                    version = '1.4'
                    body = $cardBody
                    actions = $actions
                }
            }
        )
    }

    # ── Send ────────────────────────────────────────────────────────
    $json = $card | ConvertTo-Json -Depth 20 -Compress

    try {
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $json -ContentType 'application/json; charset=utf-8' -ErrorAction Stop | Out-Null
        Write-Host "  📨 Teams notification sent ($statusText)" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to send Teams notification: $($_.Exception.Message)"
    }
}
