<#
.SYNOPSIS
    Automates the full Maester GitHub Actions setup — from 17 manual steps to one command.

.DESCRIPTION
    Creates an Entra application, grants all required Microsoft Graph permissions,
    adds a federated identity credential for GitHub Actions OIDC, and sets the
    GitHub secrets on the target repository.

    Follows the official Maester setup guide:
    https://maester.dev/docs/monitoring/github#set-up-the-github-actions-workflow

    No parameters required — runs interactively with sensible defaults.
    All defaults can be overridden via parameters.

.PARAMETER DisplayName
    Display name for the Entra application. Default: "Maester DevOps Account"

.PARAMETER GitHubRepo
    GitHub repository in "owner/repo" format. Default: auto-detected from the
    current git remote (origin).

.PARAMETER GitHubBranch
    Branch name for the federated identity credential. Default: "main"

.PARAMETER FICName
    Name for the federated identity credential. Default: "maester-devops"

.PARAMETER IncludeExchange
    Grant Exchange Online permissions (Exchange.ManageAsApp).

.PARAMETER IncludeTeams
    Grant Teams permissions (needed for Teams CISA tests).

.PARAMETER IncludeTCM
    Grant TCM permissions (ConfigurationMonitoring.ReadWrite.All) for EasyTCM integration.

.PARAMETER SkipGitHubSecrets
    Skip setting GitHub secrets (useful if you want to set them manually).

.EXAMPLE
    # Zero parameters — auto-detects repo, uses all defaults
    .\New-MaesterServicePrincipal.ps1

.EXAMPLE
    # Override app name and target a specific repo
    .\New-MaesterServicePrincipal.ps1 -DisplayName "Contoso Maester" -GitHubRepo "contoso/maester-tests"

.EXAMPLE
    # Include Exchange + TCM permissions
    .\New-MaesterServicePrincipal.ps1 -IncludeExchange -IncludeTCM

.NOTES
    Prerequisites:
    - Microsoft.Graph.Authentication module (Install-Module Microsoft.Graph.Authentication)
    - GitHub CLI (gh) authenticated — https://cli.github.com/
    - Global Admin or Application Administrator role for permission grants

    Author: Loïc MICHEL (@yourfriendlycloud)
    License: MIT
    Repo: https://github.com/kayasax/EasyTCM
#>

[CmdletBinding()]
param(
    [string]$DisplayName = "Maester DevOps Account",
    [string]$GitHubRepo,
    [string]$GitHubBranch = "main",
    [string]$FICName = "maester-devops",
    [switch]$IncludeExchange,
    [switch]$IncludeTeams,
    [switch]$IncludeTCM,
    [switch]$SkipGitHubSecrets
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Helpers ─────────────────────────────────────────────────────────────────

function Write-Step {
    param([int]$Number, [int]$Total, [string]$Message)
    Write-Host "`n[ $Number/$Total ] " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

function Assert-Prerequisite {
    param([string]$Module, [string]$Command, [string]$HelpUrl)
    if ($Module -and -not (Get-Module -ListAvailable -Name $Module)) {
        throw "Required module '$Module' is not installed. Install it with: Install-Module $Module -Scope CurrentUser`nMore info: $HelpUrl"
    }
    if ($Command -and -not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "Required command '$Command' is not available. Install it from: $HelpUrl"
    }
}

# ── Banner ──────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Maester GitHub Actions — Automated Setup                ║" -ForegroundColor Cyan
Write-Host "║   From 17 manual steps to one command                    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$totalSteps = if ($SkipGitHubSecrets) { 5 } else { 6 }

# ── Step 1: Prerequisites ──────────────────────────────────────────────────

Write-Step 1 $totalSteps "Checking prerequisites..."

Assert-Prerequisite -Module 'Microsoft.Graph.Authentication' -HelpUrl 'https://learn.microsoft.com/powershell/microsoftgraph/installation'

if (-not $SkipGitHubSecrets) {
    Assert-Prerequisite -Command 'gh' -HelpUrl 'https://cli.github.com/'
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
    }
    Write-Host "  ✓ gh CLI authenticated" -ForegroundColor Green
}

# Auto-detect GitHub repo if not specified
if (-not $GitHubRepo) {
    $remoteUrl = git remote get-url origin 2>$null
    if ($remoteUrl -match 'github\.com[:/](.+?)(?:\.git)?$') {
        $GitHubRepo = $Matches[1]
        Write-Host "  ✓ Auto-detected repo: $GitHubRepo" -ForegroundColor Green
    }
    else {
        throw "Could not detect GitHub repo from git remote. Use -GitHubRepo 'owner/repo' explicitly."
    }
}
else {
    Write-Host "  ✓ Target repo: $GitHubRepo" -ForegroundColor Green
}

# Connect to Graph if not already connected
$ctx = Get-MgContext
if (-not $ctx) {
    Write-Host "  Connecting to Microsoft Graph (a browser window will open)..."
    Connect-MgGraph -Scopes 'Application.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All', 'Directory.Read.All' -NoWelcome
    $ctx = Get-MgContext
}
else {
    # Verify we have the right scopes
    $needed = @('Application.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All')
    $missing = $needed | Where-Object { $ctx.Scopes -notcontains $_ }
    if ($missing) {
        Write-Host "  Reconnecting with required scopes..."
        Connect-MgGraph -Scopes 'Application.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All', 'Directory.Read.All' -NoWelcome
        $ctx = Get-MgContext
    }
}
Write-Host "  ✓ Connected as $($ctx.Account) to tenant $($ctx.TenantId)" -ForegroundColor Green

# ── Step 2: App Registration ───────────────────────────────────────────────

Write-Step 2 $totalSteps "Creating Entra application '$DisplayName'..."

# Check if app already exists
$existing = Get-MgApplication -Filter "displayName eq '$DisplayName'" -Top 1
if ($existing) {
    Write-Host "  ⚠ Application '$DisplayName' already exists (AppId: $($existing.AppId))" -ForegroundColor Yellow
    $confirm = Read-Host "  Use existing app? (Y/n)"
    if ($confirm -eq 'n') {
        throw "Aborted. Use -DisplayName to specify a different name."
    }
    $app = $existing
}
else {
    $app = New-MgApplication -DisplayName $DisplayName -SignInAudience 'AzureADMyOrg' `
        -Notes "Created by New-MaesterServicePrincipal for GitHub Actions automation ($GitHubRepo)"
    Write-Host "  ✓ Created application (AppId: $($app.AppId))" -ForegroundColor Green
}

# Ensure service principal exists
$sp = Get-MgServicePrincipal -Filter "appId eq '$($app.AppId)'" -Top 1
if (-not $sp) {
    $sp = New-MgServicePrincipal -AppId $app.AppId
    Write-Host "  ✓ Created service principal (ObjectId: $($sp.Id))" -ForegroundColor Green
}
else {
    Write-Host "  ✓ Service principal exists (ObjectId: $($sp.Id))" -ForegroundColor Green
}

# ── Step 3: Grant permissions ───────────────────────────────────────────────

Write-Step 3 $totalSteps "Granting Microsoft Graph permissions (with admin consent)..."

$graphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

# Maester core permissions (from https://maester.dev/docs/monitoring/github)
$permissions = @(
    'DeviceManagementConfiguration.Read.All'
    'DeviceManagementManagedDevices.Read.All'
    'DeviceManagementRBAC.Read.All'
    'Directory.Read.All'
    'DirectoryRecommendations.Read.All'
    'IdentityRiskEvent.Read.All'
    'OnPremDirectorySynchronization.Read.All'
    'Policy.Read.All'
    'Policy.Read.ConditionalAccess'
    'PrivilegedAccess.Read.AzureAD'
    'Reports.Read.All'
    'ReportSettings.Read.All'
    'RoleEligibilitySchedule.Read.Directory'
    'RoleManagement.Read.All'
    'SecurityIdentitiesSensors.Read.All'
    'SecurityIdentitiesHealth.Read.All'
    'SharePointTenantSettings.Read.All'
    'ThreatHunting.Read.All'
    'UserAuthenticationMethod.Read.All'
)

if ($IncludeTeams) {
    # Teams-related permissions for CISA Teams tests
    $permissions += @(
        'TeamSettings.Read.All'
        'Channel.ReadBasic.All'
    )
    Write-Host "  + Including Teams permissions" -ForegroundColor DarkCyan
}

if ($IncludeTCM) {
    $permissions += 'ConfigurationMonitoring.ReadWrite.All'
    Write-Host "  + Including TCM permissions (EasyTCM)" -ForegroundColor DarkCyan
}

# Get existing assignments to avoid duplicates
$existingAssignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id
$grantedCount = 0
$skippedCount = 0

foreach ($permName in $permissions) {
    $role = $graphSp.AppRoles | Where-Object { $_.Value -eq $permName }
    if (-not $role) {
        Write-Host "  ⚠ Not found in Graph: $permName" -ForegroundColor Yellow
        continue
    }

    # Skip if already granted
    if ($existingAssignments | Where-Object { $_.AppRoleId -eq $role.Id }) {
        $skippedCount++
        continue
    }

    try {
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id `
            -PrincipalId $sp.Id -ResourceId $graphSp.Id `
            -AppRoleId $role.Id -ErrorAction Stop | Out-Null
        $grantedCount++
    }
    catch {
        Write-Warning "  Failed to grant $permName : $($_.Exception.Message)"
    }
}

Write-Host "  ✓ $grantedCount permissions granted, $skippedCount already existed" -ForegroundColor Green

# Exchange Online permissions (separate SP)
if ($IncludeExchange) {
    Write-Host "  + Granting Exchange Online permissions..." -ForegroundColor DarkCyan
    $exoSp = Get-MgServicePrincipal -Filter "appId eq '00000002-0000-0ff1-ce00-000000000000'" -Top 1
    if ($exoSp) {
        $exoRole = $exoSp.AppRoles | Where-Object { $_.Value -eq 'Exchange.ManageAsApp' }
        if ($exoRole) {
            $exoExisting = $existingAssignments | Where-Object { $_.AppRoleId -eq $exoRole.Id }
            if (-not $exoExisting) {
                try {
                    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id `
                        -PrincipalId $sp.Id -ResourceId $exoSp.Id `
                        -AppRoleId $exoRole.Id -ErrorAction Stop | Out-Null
                    Write-Host "  ✓ Exchange.ManageAsApp granted" -ForegroundColor Green
                }
                catch {
                    Write-Warning "  Failed to grant Exchange.ManageAsApp: $($_.Exception.Message)"
                }
            }
            else {
                Write-Host "  ✓ Exchange.ManageAsApp already granted" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Warning "  Exchange Online service principal not found — is Exchange Online enabled in this tenant?"
    }

    Write-Host ""
    Write-Host "  ⚠ Exchange Online also requires an Entra role assignment:" -ForegroundColor Yellow
    Write-Host "    Assign 'Exchange Administrator' or 'Global Reader' to the service principal." -ForegroundColor Yellow
    Write-Host "    ObjectId: $($sp.Id)" -ForegroundColor Yellow
}

# ── Step 4: Federated Identity Credential ──────────────────────────────────

Write-Step 4 $totalSteps "Adding federated identity credential for GitHub Actions OIDC..."

$existingFic = Get-MgApplicationFederatedIdentityCredential -ApplicationId $app.Id |
    Where-Object { $_.Name -eq $FICName }

if ($existingFic) {
    Write-Host "  ✓ FIC '$FICName' already exists" -ForegroundColor Green
}
else {
    $ficParams = @{
        Name        = $FICName
        Issuer      = "https://token.actions.githubusercontent.com"
        Subject     = "repo:${GitHubRepo}:ref:refs/heads/${GitHubBranch}"
        Audiences   = @("api://AzureADTokenExchange")
        Description = "GitHub Actions OIDC for $GitHubRepo ($GitHubBranch branch)"
    }
    New-MgApplicationFederatedIdentityCredential -ApplicationId $app.Id -BodyParameter $ficParams | Out-Null
    Write-Host "  ✓ FIC created: repo:${GitHubRepo}:ref:refs/heads/${GitHubBranch}" -ForegroundColor Green
}

# ── Step 5: GitHub Secrets ──────────────────────────────────────────────────

if (-not $SkipGitHubSecrets) {
    Write-Step 5 $totalSteps "Setting GitHub secrets on $GitHubRepo..."

    gh secret set AZURE_TENANT_ID --repo $GitHubRepo --body $ctx.TenantId 2>&1 | Out-Null
    Write-Host "  ✓ AZURE_TENANT_ID set" -ForegroundColor Green

    gh secret set AZURE_CLIENT_ID --repo $GitHubRepo --body $app.AppId 2>&1 | Out-Null
    Write-Host "  ✓ AZURE_CLIENT_ID set" -ForegroundColor Green
}

# ── Summary ─────────────────────────────────────────────────────────────────

$stepNum = if ($SkipGitHubSecrets) { 5 } else { 6 }
Write-Step $stepNum $totalSteps "Done!"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✅ Maester GitHub Actions setup complete!               ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Application:     $DisplayName" -ForegroundColor White
Write-Host "  App (Client) ID: $($app.AppId)" -ForegroundColor White
Write-Host "  Tenant ID:       $($ctx.TenantId)" -ForegroundColor White
Write-Host "  SP Object ID:    $($sp.Id)" -ForegroundColor White
Write-Host "  GitHub repo:     $GitHubRepo" -ForegroundColor White
Write-Host "  FIC subject:     repo:${GitHubRepo}:ref:refs/heads/${GitHubBranch}" -ForegroundColor White
Write-Host ""
Write-Host "  Permissions:     $($permissions.Count) Graph app roles" -ForegroundColor White
if ($IncludeExchange) { Write-Host "                   + Exchange.ManageAsApp" -ForegroundColor White }
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "  1. Add the Maester GitHub Actions workflow to your repo" -ForegroundColor White
Write-Host "     https://maester.dev/docs/monitoring/github" -ForegroundColor DarkGray
Write-Host "  2. Trigger the workflow from the Actions tab" -ForegroundColor White
Write-Host "  3. Download the Maester HTML report from the artifacts" -ForegroundColor White
Write-Host ""

# Return object for pipeline use
[PSCustomObject]@{
    DisplayName   = $DisplayName
    AppId         = $app.AppId
    ObjectId      = $app.Id
    SPObjectId    = $sp.Id
    TenantId      = $ctx.TenantId
    GitHubRepo    = $GitHubRepo
    GitHubBranch  = $GitHubBranch
    Permissions   = $permissions
}
