# EasyTCM Module Loader
# Dot-sources all private and public functions

$Private = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)
$Public  = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)

foreach ($file in @($Private + $Public)) {
    try {
        . $file.FullName
    }
    catch {
        Write-Error "Failed to import function $($file.FullName): $_"
    }
}

# Module-level constants
$script:TCM_BASE_URL      = 'https://graph.microsoft.com/beta/admin/configurationManagement'
$script:TCM_APP_ID        = '03b07b79-c5bc-4b5e-9bfa-13acf4a99998'
$script:TCM_GRAPH_SCOPES  = @(
    'ConfigurationMonitoring.Read.All'
    'ConfigurationMonitoring.ReadWrite.All'
)

# File-based cache for Compare-TCMBaseline results (survives module reimports)
$script:CompareBaselineCachePath = Join-Path ([System.IO.Path]::GetTempPath()) 'EasyTCM-CompareBaselineCache.json'
