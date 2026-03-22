function Register-TCMSchedule {
    <#
    .SYNOPSIS
        One command to set up automated drift monitoring with Teams notifications.
    .DESCRIPTION
        Fully automated setup — just run this while connected to Microsoft Graph.

        The TCM API requires delegated (user) authentication. This command:
        1. Validates your current Graph connection and TCM access
        2. Acquires a token via device code flow and caches the refresh token
           (DPAPI-encrypted on disk, only accessible by your user account)
        3. Registers a scheduled task that silently refreshes the token each run

        The refresh token typically lasts 90 days. If it expires, re-run this command.

        Prerequisites:
        - Connect-MgGraph with ConfigurationMonitoring.ReadWrite.All scope

    .PARAMETER WebhookUrl
        Teams incoming webhook URL for drift notifications.
    .PARAMETER Report
        Also generate an HTML report each run.
    .PARAMETER CompareBaseline
        Also detect new/deleted resources each run.
    .PARAMETER TaskName
        Name for the scheduled task. Defaults to 'EasyTCM-DriftCheck'.
    .PARAMETER IntervalHours
        Hours between runs. Defaults to 6 (matches TCM cycle).
    .EXAMPLE
        # One command — everything is automated
        Register-TCMSchedule -WebhookUrl 'https://contoso.webhook.office.com/...'

    .EXAMPLE
        # With HTML report and baseline comparison
        Register-TCMSchedule -WebhookUrl $url -Report -CompareBaseline
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$WebhookUrl,

        [switch]$Report,
        [switch]$CompareBaseline,

        [string]$TaskName = 'EasyTCM-DriftCheck',

        [ValidateRange(1, 24)]
        [int]$IntervalHours = 6
    )

    # ── Step 1: Validate prerequisites ──────────────────────────────
    Write-Host ''
    Write-Host '[ 1/4 ] Checking prerequisites...' -ForegroundColor Cyan

    $mgContext = Get-MgContext
    if (-not $mgContext) {
        throw 'Not connected to Microsoft Graph. Run: Connect-MgGraph -Scopes "ConfigurationMonitoring.ReadWrite.All"'
    }
    if ($mgContext.AuthType -ne 'Delegated') {
        throw 'TCM requires delegated (user) authentication. Run: Connect-MgGraph -Scopes "ConfigurationMonitoring.ReadWrite.All"'
    }

    $tenantId = $mgContext.TenantId
    $clientId = $mgContext.ClientId
    Write-Host "  Graph: delegated session on tenant $tenantId" -ForegroundColor Green

    $testOk = Test-TCMConnection -Quiet
    if (-not $testOk) {
        throw 'Cannot reach TCM API. Ensure you have the ConfigurationMonitoring.ReadWrite.All scope.'
    }
    Write-Host '  TCM API: reachable' -ForegroundColor Green

    # ── Step 2: Acquire token with device code and store refresh token ──
    Write-Host ''
    Write-Host '[ 2/4 ] Authenticating for scheduled task (one-time device code)...' -ForegroundColor Cyan

    # Load the MSAL library from the Graph SDK dependency
    $msalAssembly = [Microsoft.Identity.Client.PublicClientApplicationBuilder].Assembly
    Write-Host "  MSAL: loaded ($($msalAssembly.GetName().Version))" -ForegroundColor DarkGray

    $scopes = @('https://graph.microsoft.com/.default')

    $appBuilder = [Microsoft.Identity.Client.PublicClientApplicationBuilder]::Create($clientId)
    $appBuilder = $appBuilder.WithAuthority("https://login.microsoftonline.com/$tenantId")

    # Set up file-based token cache
    $credStorePath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'EasyTCM'
    if (-not (Test-Path $credStorePath)) {
        New-Item -ItemType Directory -Path $credStorePath -Force | Out-Null
    }
    $cachePath = Join-Path $credStorePath "$TaskName.msalcache.bin"

    $app = $appBuilder.Build()

    # Register DPAPI-encrypted file cache
    $cacheHelper = [Microsoft.Identity.Client.Extensions.Msal.MsalCacheHelper]
    if ($cacheHelper) {
        $storageProps = [Microsoft.Identity.Client.Extensions.Msal.StorageCreationPropertiesBuilder]::new(
            "$TaskName.msalcache.bin", $credStorePath
        ).Build()
        $helper = [Microsoft.Identity.Client.Extensions.Msal.MsalCacheHelper]::CreateAsync($storageProps).GetAwaiter().GetResult()
        $helper.RegisterCache($app.UserTokenCache)
        Write-Host "  Token cache: $cachePath (DPAPI encrypted)" -ForegroundColor DarkGray
    }
    else {
        Write-Warning '  MSAL cache extensions not available — using unprotected cache as fallback.'
        # Manual file cache fallback
        $app.UserTokenCache.SetBeforeAccessAsync({
            param($args)
            if (Test-Path $cachePath) {
                $args.TokenCache.DeserializeMsalV3([System.IO.File]::ReadAllBytes($cachePath))
            }
        })
        $app.UserTokenCache.SetAfterAccessAsync({
            param($args)
            if ($args.HasStateChanged) {
                [System.IO.File]::WriteAllBytes($cachePath, $args.TokenCache.SerializeMsalV3())
            }
        })
    }

    # Try silent first (if cache exists), otherwise do device code
    $account = $null
    try {
        $accounts = $app.GetAccountsAsync().GetAwaiter().GetResult()
        if ($accounts -and $accounts.Count -gt 0) {
            $account = $accounts | Select-Object -First 1
        }
    }
    catch { Write-Debug "No cached accounts: $_" }

    $authResult = $null
    if ($account) {
        try {
            $authResult = $app.AcquireTokenSilent($scopes, $account).ExecuteAsync().GetAwaiter().GetResult()
            Write-Host "  Reusing cached token for $($authResult.Account.Username)" -ForegroundColor Green
        }
        catch { $authResult = $null }
    }

    if (-not $authResult) {
        Write-Host ''
        Write-Host '  ⬇ A device code will appear — authenticate in your browser.' -ForegroundColor Yellow
        Write-Host ''

        $deviceCodeCallback = [System.Func[Microsoft.Identity.Client.DeviceCodeResult, System.Threading.Tasks.Task]] {
            param($dcr)
            Write-Host "  $($dcr.Message)" -ForegroundColor White
            return [System.Threading.Tasks.Task]::CompletedTask
        }

        if (-not $PSCmdlet.ShouldProcess('Device code authentication', 'Authenticate')) { return }

        $authResult = $app.AcquireTokenByDeviceCode($scopes, $deviceCodeCallback).ExecuteAsync().GetAwaiter().GetResult()
        Write-Host ''
        Write-Host "  Authenticated as $($authResult.Account.Username)" -ForegroundColor Green
    }

    Write-Host "  Token cached for scheduled task reuse" -ForegroundColor DarkGray

    # ── Step 3: Build the task command ──────────────────────────────
    Write-Host ''
    Write-Host '[ 3/4 ] Building scheduled task...' -ForegroundColor Cyan

    $cmd = 'Show-TCMDrift -Notify Teams'
    if ($Report) { $cmd += ' -Report' }
    if ($CompareBaseline) { $cmd += ' -CompareBaseline' }

    $modInfo = Get-Module EasyTCM -ListAvailable | Select-Object -First 1
    if (-not $modInfo) {
        throw 'EasyTCM module not found. Install it first: Install-Module EasyTCM'
    }
    $modulePath = $modInfo.ModuleBase
    $importCmd = "Import-Module '$modulePath\\EasyTCM.psd1'"
    $envSetup = "`$env:EASYTCM_WEBHOOK_URL = '$WebhookUrl'"

    # The task script acquires a token silently from the cached refresh token,
    # then passes it to Connect-MgGraph -AccessToken
    $authScript = @"
`$ErrorActionPreference = 'Stop'
`$app = [Microsoft.Identity.Client.PublicClientApplicationBuilder]::Create('$clientId').WithAuthority('https://login.microsoftonline.com/$tenantId').Build()
`$storageProps = [Microsoft.Identity.Client.Extensions.Msal.StorageCreationPropertiesBuilder]::new('$TaskName.msalcache.bin','$credStorePath').Build()
`$helper = [Microsoft.Identity.Client.Extensions.Msal.MsalCacheHelper]::CreateAsync(`$storageProps).GetAwaiter().GetResult()
`$helper.RegisterCache(`$app.UserTokenCache)
`$acct = (`$app.GetAccountsAsync().GetAwaiter().GetResult()) | Select-Object -First 1
`$token = `$app.AcquireTokenSilent(@('https://graph.microsoft.com/.default'),`$acct).ExecuteAsync().GetAwaiter().GetResult()
Connect-MgGraph -AccessToken (ConvertTo-SecureString `$token.AccessToken -AsPlainText -Force) -NoWelcome
"@
    $scriptBlock = "$envSetup; $importCmd; $authScript; $cmd"

    # ── Step 4: Register the task ───────────────────────────────────
    Write-Host ''
    Write-Host '[ 4/4 ] Registering scheduled task...' -ForegroundColor Cyan

    if ($IsWindows -or (-not $PSVersionTable.PSEdition) -or ($PSVersionTable.PSEdition -eq 'Desktop')) {
        $pwshPath = if (Get-Command pwsh -ErrorAction SilentlyContinue) {
            (Get-Command pwsh).Source
        } else {
            (Get-Command powershell).Source
        }

        $encodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($scriptBlock))
        $action = New-ScheduledTaskAction -Execute $pwshPath -Argument "-NoProfile -NonInteractive -EncodedCommand $encodedCmd"
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddHours(6) -RepetitionInterval (New-TimeSpan -Hours $IntervalHours)
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries

        if ($PSCmdlet.ShouldProcess($TaskName, 'Register scheduled task')) {
            Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description "EasyTCM drift check with Teams notification (every ${IntervalHours}h)" -Force

            Write-Host ''
            Write-Host "  ✅ Drift monitoring is ready!" -ForegroundColor Green
            Write-Host "     Runs every ${IntervalHours}h | Silent token refresh | Notifies Teams" -ForegroundColor DarkGray
            Write-Host ''
            Write-Host '  Commands:' -ForegroundColor DarkGray
            Write-Host "    Start-ScheduledTask '$TaskName'      # run now" -ForegroundColor DarkGray
            Write-Host "    Get-ScheduledTask '$TaskName'        # check status" -ForegroundColor DarkGray
            Write-Host "    Unregister-ScheduledTask '$TaskName' # remove" -ForegroundColor DarkGray
            Write-Host '    Register-TCMSchedule ...              # re-auth if token expires' -ForegroundColor DarkGray
            Write-Host ''
        }
    }
    else {
        $cronInterval = if ($IntervalHours -eq 1) { '0 * * * *' }
                        elseif (24 % $IntervalHours -eq 0) { "0 */$IntervalHours * * *" }
                        else { "0 */$IntervalHours * * *" }

        $cronCmd = "EASYTCM_WEBHOOK_URL='$WebhookUrl' pwsh -NoProfile -Command '$importCmd; $authScript; $cmd'"

        Write-Host ''
        Write-Host '  Add this line to your crontab (crontab -e):' -ForegroundColor Cyan
        Write-Host ''
        Write-Host "  $cronInterval $cronCmd" -ForegroundColor White
        Write-Host ''
    }
}
