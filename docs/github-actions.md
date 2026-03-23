---
layout: default
title: "GitHub Actions — Maester + TCM Continuous Monitoring"
---

# 🚀 GitHub Actions: Maester + TCM Continuous Monitoring

**Automated daily M365 security checks (Maester) and drift detection (EasyTCM) — unified HTML report, zero servers.**

Two workflows are provided in `.github/workflows/`:

| Workflow | Purpose |
|----------|---------|
| [`maester.yml`](https://github.com/kayasax/EasyTCM/blob/main/.github/workflows/maester.yml) | **Phase 1** — Vanilla Maester: 400+ built-in security checks |
| [`maester-tcm.yml`](https://github.com/kayasax/EasyTCM/blob/main/.github/workflows/maester-tcm.yml) | **Phase 2** — Maester + EasyTCM: security checks AND drift detection in one report |

> **Recommended path:** get Phase 1 working first. It validates your app registration, permissions, and runner setup. Once the vanilla Maester report is green, adding TCM (Phase 2) is a one-step change.

---

## Prerequisites

### 1. Entra ID App Registration

Create one app registration that both workflows share. It needs the Microsoft Graph **application permissions** listed below.

#### Maester-only permissions (Phase 1)

These are the same permissions Maester's official documentation requires:

| Permission | Type |
|-----------|------|
| `DeviceManagementConfiguration.Read.All` | Application |
| `DeviceManagementManagedDevices.Read.All` | Application |
| `DeviceManagementRBAC.Read.All` | Application |
| `Directory.Read.All` | Application |
| `DirectoryRecommendations.Read.All` | Application |
| `IdentityRiskEvent.Read.All` | Application |
| `OnPremDirectorySynchronization.Read.All` | Application |
| `Policy.Read.All` | Application |
| `Policy.Read.ConditionalAccess` | Application |
| `PrivilegedAccess.Read.AzureAD` | Application |
| `Reports.Read.All` | Application |
| `ReportSettings.Read.All` | Application |
| `RoleEligibilitySchedule.Read.Directory` | Application |
| `RoleManagement.Read.All` | Application |
| `SecurityIdentitiesSensors.Read.All` | Application |
| `SecurityIdentitiesHealth.Read.All` | Application |
| `SharePointTenantSettings.Read.All` | Application |
| `ThreatHunting.Read.All` | Application |
| `UserAuthenticationMethod.Read.All` | Application |

> For the full, up-to-date Maester permission list see [maester.dev/docs/monitoring/github](https://maester.dev/docs/monitoring/github).

#### Additional permissions for TCM (Phase 2 only)

| Permission | Type | Why |
|-----------|------|-----|
| `ConfigurationMonitoring.ReadWrite.All` | Application | Access TCM APIs (drift data, monitors, baselines) |

> **One-time requirement:** The TCM service principal must be provisioned before the workflow runs. Do this once interactively: `Initialize-TCM` (or `Start-TCMMonitoring` from any machine with Global Admin). The GitHub Actions workflow does not need `Application.ReadWrite.All` after that.

### 2. Workload Identity Federation (preferred) or Client Secret

Choose **one** of the two authentication methods:

#### Option A — Workload Identity Federation (recommended)

No secret rotation. Microsoft Entra verifies the GitHub OIDC token directly.

1. In your app registration → **Certificates & secrets** → **Federated credentials** → **Add credential**
2. Scenario: **GitHub Actions deploying Azure resources**
3. Fill in:
   - Organization: `<your-github-org-or-username>`
   - Repository: `<your-repo-name>`
   - Entity: `Branch` → `main` (or `Environment` for tighter control)
4. **Do not set `AZURE_CLIENT_SECRET`** — set the repository variable `USE_CLIENT_SECRET` to `false` (or leave it unset)

#### Option B — Client Secret

Simpler but requires periodic rotation.

1. In your app registration → **Certificates & secrets** → **Client secrets** → **New client secret**
2. Copy the **Value** (shown only once)
3. Add it as GitHub secret `AZURE_CLIENT_SECRET` (see below)
4. Set repository variable `USE_CLIENT_SECRET` to `true`

### 3. GitHub Secrets and Variables

Go to your repository → **Settings** → **Secrets and variables** → **Actions**.

#### Secrets (encrypted)

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | Application (client) ID of your app registration |
| `AZURE_TENANT_ID` | Directory (tenant) ID |
| `AZURE_CLIENT_SECRET` | *(Option B only)* Client secret value |

#### Variables (plain text)

| Variable | Value | Default |
|----------|-------|---------|
| `USE_CLIENT_SECRET` | `true` (Option B) or `false` / unset (Option A) | unset = OIDC |

---

## Phase 1: Vanilla Maester Workflow

File: [`.github/workflows/maester.yml`](https://github.com/kayasax/EasyTCM/blob/main/.github/workflows/maester.yml)

```yaml
# Runs daily at 06:00 UTC and on manual trigger
on:
  schedule:
    - cron: '0 6 * * *'
  workflow_dispatch:
```

### What it does

1. Authenticates to Microsoft Graph (OIDC or client secret)
2. Installs Maester and downloads the 400+ built-in test suite
3. Runs `Invoke-Maester` — all security checks
4. Uploads the HTML report as a GitHub Actions artifact

### Running it

Push the workflow file to your repo. Then:

- **Manual:** Actions tab → **Maester — M365 Security Checks** → **Run workflow**
- **Scheduled:** runs automatically at 06:00 UTC

### Verifying the output

1. Open the completed workflow run in the Actions tab
2. Click **Artifacts** → download `maester-report`
3. Open `MaesterReport.html` in a browser

A green report with 0 failures confirms your app registration, permissions, and runner are all correct. This is your baseline before adding TCM.

---

## Phase 2: Maester + TCM Drift Detection Workflow

File: [`.github/workflows/maester-tcm.yml`](https://github.com/kayasax/EasyTCM/blob/main/.github/workflows/maester-tcm.yml)

This extends Phase 1 with a **TCM drift step** that runs before `Invoke-Maester`. Drift results appear as Pester tests in the same HTML report alongside Maester's built-in checks.

```
✅ 423 Maester security checks passed
❌ 2 TCM drift tests FAILED
   → conditionalaccesspolicy: excludeUsers changed [] → ["breakglass@contoso.com"]
   → namedlocation: ipRanges changed
✅ 15 TCM drift tests passed (no changes)
```

### What it adds

```yaml
- name: Sync TCM drift to Maester
  shell: pwsh
  env:
    MAESTER_TESTS_PATH: ${{ github.workspace }}
  run: |
    Import-Module EasyTCM
    Sync-TCMDriftToMaester   # inject drift test files
```

`Sync-TCMDriftToMaester` writes:

```
maester-tests/
└── Drift/
    └── TCM-EasyTCM Recommended/
        ├── baseline.json         ← approved state
        ├── current.json          ← current state (baseline + drifts applied)
        └── TCM-Drift.Tests.ps1   ← auto-generated Pester tests
```

`Invoke-Maester` then discovers those test files automatically.

### Workflow failure = free alerting

When drift is detected, the Pester tests fail → the workflow step fails → GitHub marks the run as failed → **GitHub's native notifications** alert all repository watchers. No extra alerting setup needed.

### Running it for the first time

**Before** running this workflow, ensure the TCM service principal is provisioned:

```powershell
# Run once interactively (requires Global Admin on first run)
Connect-MgGraph -Scopes 'Application.ReadWrite.All','ConfigurationMonitoring.ReadWrite.All'
Import-Module EasyTCM
Initialize-TCM
```

After that, the GitHub Actions service principal only needs `ConfigurationMonitoring.ReadWrite.All`.

---

## Customization

### Change the schedule

Edit the `cron` expression in the workflow file:

```yaml
# Every 6 hours (matches TCM's monitoring cycle)
- cron: '0 */6 * * *'

# Weekdays only at 07:30 UTC
- cron: '30 7 * * 1-5'
```

### Change the monitoring profile

`Show-TCMDrift -Maester` uses the monitors already configured in your tenant. To scope the monitor to a different profile, run once interactively:

```powershell
# Security-critical resources only (lower quota impact)
Start-TCMMonitoring -Profile SecurityCritical

# Broader coverage
Start-TCMMonitoring -Profile Recommended
```

### Add baseline comparison (detect new/deleted resources)

TCM drift only detects **property changes** on resources already in the baseline. To also catch new CA policies or deleted transport rules, add `-CompareBaseline`:

```powershell
Show-TCMDrift -Maester -CompareBaseline
```

> ⚠️ `-CompareBaseline` takes a fresh snapshot (counts against your daily quota). Use it no more than once per day.

---

## Troubleshooting

### `Test-TCMConnection` fails with "insufficient privileges"

The app registration is missing `ConfigurationMonitoring.ReadWrite.All`. Grant it in the Azure portal and **re-grant admin consent**.

### "No monitors found" or empty drift results

The TCM service principal has not been provisioned yet. Run `Initialize-TCM` or `Start-TCMMonitoring` interactively once.

### OIDC authentication fails

Verify the federated credential in your app registration matches the exact organization, repository, and branch of your GitHub Actions workflow. Check that `id-token: write` is in your workflow permissions.

### Maester reports 0 tests

`Install-MaesterTests` failed silently. Check runner connectivity to the PowerShell Gallery. On corporate runners behind a proxy, set `HTTP_PROXY` / `HTTPS_PROXY` environment variables.

### Quota exceeded errors

Use `Get-TCMQuota` interactively to check your remaining quota. Consider switching to `SecurityCritical` profile or reducing the workflow schedule frequency.

---

## Notification Channels

GitHub's native notifications handle alerting when the workflow fails. To add extra channels:

**Microsoft Teams** — add a step that posts to a webhook on failure:

```yaml
- name: Notify Teams on drift
  if: failure()
  shell: pwsh
  env:
    TEAMS_WEBHOOK_URI: ${{ secrets.TEAMS_WEBHOOK_URI }}
  run: |
    $body = @{
      text = "⚠️ EasyTCM detected M365 tenant drift. See the workflow run for details."
    } | ConvertTo-Json
    Invoke-RestMethod -Uri $env:TEAMS_WEBHOOK_URI -Method Post `
        -Body $body -ContentType 'application/json'
```

**Email** — GitHub's built-in notification emails are sent to repository watchers for every failed run. No extra configuration needed.

---

## Automated Setup Script

Don't want to click through 17 manual steps? The [`New-MaesterServicePrincipal.ps1`](https://github.com/kayasax/EasyTCM/blob/main/scripts/New-MaesterServicePrincipal.ps1) script automates the entire setup:

```powershell
# Zero parameters — auto-detects repo from git remote, uses sensible defaults
.\scripts\New-MaesterServicePrincipal.ps1

# Override app name and include TCM permissions
.\scripts\New-MaesterServicePrincipal.ps1 -DisplayName "Contoso Maester" -IncludeTCM

# Include Exchange + Teams permissions for full CISA coverage
.\scripts\New-MaesterServicePrincipal.ps1 -IncludeExchange -IncludeTeams -IncludeTCM
```

The script creates the app registration, grants all permissions with admin consent, adds the federated identity credential, and sets the GitHub secrets — all in one command.

---

## [← Continuous Monitoring Guide](continuous-monitoring)
## [← Maester Integration](maester-integration)
## [← Back to Home](.)
