# Getting Started with EasyTCM

This guide walks you through setting up EasyTCM and running your first configuration monitoring workflow in under 10 minutes.

## Prerequisites

| What | Why | How |
|------|-----|-----|
| PowerShell 5.1+ or 7.0+ | Module runtime | Already installed on Windows. [Install pwsh](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) for cross-platform |
| Microsoft.Graph.Authentication | Graph API connection | Auto-installed with EasyTCM |
| Entra ID privileged role | Create service principal + manage monitors | Global Admin, or Application Admin + Security Admin |
| M365 tenant | The tenant you want to monitor | Any tenant with TCM support (Global cloud) |

## Step 1: Install EasyTCM

```powershell
# From PowerShell Gallery
Install-Module -Name EasyTCM -Scope CurrentUser -Force

# Verify
Import-Module EasyTCM
Get-Command -Module EasyTCM | Measure-Object  # Should show 14 commands
```

**Or from source (development):**
```powershell
git clone https://github.com/kayasax/EasyTCM.git
Import-Module ./EasyTCM/EasyTCM/EasyTCM.psd1
```

## Step 2: Connect to Microsoft Graph

```powershell
# Connect with the required scopes
Connect-MgGraph -Scopes @(
    'Application.ReadWrite.All'          # To create TCM service principal
    'AppRoleAssignment.ReadWrite.All'    # To grant permissions
    'Policy.Read.All'                    # Entra policy access
    'RoleManagement.Read.All'            # Entra role access
    'Organization.Read.All'              # Exchange + Teams access
    'DeviceManagementConfiguration.Read.All'  # Intune access
)
```

You'll be prompted to authenticate. Use an account with sufficient privileges.

## Step 3: Initialize TCM (One-Time Setup)

```powershell
# This creates the TCM service principal and grants permissions for ALL workloads
Initialize-TCM

# Output:
# [ 1/3 ] Registering TCM service principal...
#   Created TCM service principal (ObjectId: abc123...)
# [ 2/3 ] Granting permissions to TCM service principal...
#   Granted 'User.Read.All'
#   Granted 'Policy.Read.All'
#   ...
# [ 3/3 ] Validating setup...
# TCM setup complete! You can now create monitors and snapshots.
```

> **Note:** You only need to run `Initialize-TCM` once per tenant. After that, use `Test-TCMConnection` to verify.
>
> **Security & Compliance workload:** `Initialize-TCM` automatically grants `Exchange.ManageAsApp` and assigns the `Compliance Administrator` directory role to the TCM service principal. These are required for SC resource types (DLP, retention, sensitivity labels, etc.).

## Step 4: Snapshot Your Current Configuration

```powershell
# Take a snapshot of your entire tenant
$snapshot = New-TCMSnapshot -DisplayName "My first snapshot" -Wait

# The -Wait flag polls until the snapshot completes
# Output:
# No workloads specified — snapshotting all workloads.
# Creating snapshot 'My first snapshot' with 62 resource types...
#   (Entra: 10, Exchange: 18, Intune: 1, Teams: 9, SecurityAndCompliance: 24)
#   Status: running — waiting 10s...
#   Status: running — waiting 10s...
# Snapshot completed successfully.
```

## Step 5: Convert Snapshot to Baseline (The Magic Step)

This is what makes EasyTCM unique — take your **current** config and filter it to **what actually matters** for security:

```powershell
# Default: SecurityCritical profile — CA policies, auth methods, mail security, federation
# This is quota-safe (~80-120 resources/day out of 800 limit)
$snapshotWithContent = Get-TCMSnapshot -Id $snapshot.id -IncludeContent
$baseline = ConvertTo-TCMBaseline -SnapshotContent $snapshotWithContent.snapshotContent

# Output:
# Profile 'SecurityCritical': filtering to 16 resource types
# Converted 23 resources into baseline.
#   Quota impact: 92 / 800 resources per day (11.5%)
#   Filtered out: 187 instances across 36 resource types (not in 'SecurityCritical' profile)
```

> **Why SecurityCritical is the default:** TCM's 800 resources/day limit means you can
> realistically monitor ~200 instances. SecurityCritical covers Conditional Access, auth
> methods, mail security, and federation — the configs where drift = breach. That's 80%
> of the attack surface in ~15% of the quota.
>
> Use `-Profile Recommended` for broader coverage, or `-Profile Full` if your tenant has
> very few resource instances.

## Step 6: Create a Monitor

```powershell
# Create a monitor that checks for drift every 6 hours
$monitor = New-TCMMonitor -DisplayName "Entra Baseline Monitor" -Baseline $baseline

# Output:
# Creating monitor 'Entra Baseline Monitor' with 42 resources...
#   Daily resource usage: 168 / 800 quota
# Monitor created (Id: bf77ee1e-..., Status: active)
#   Runs every 6 hours at fixed GMT times: 6 AM, 12 PM, 6 PM, 12 AM
```

## Step 7: Check for Drifts

After the monitor has run at least once (within 6 hours of creation):

```powershell
# See all active drifts
Get-TCMDrift | Format-Table Workload, ResourceType, ResourceDisplay, DriftedPropertyCount, Status

# Example output:
# Workload  ResourceType                        ResourceDisplay     DriftedPropertyCount  Status
# --------  ------------                        ---------------     --------------------  ------
# Exchange  microsoft.exchange.accepteddomain   contoso.com         1                     active
# Entra     microsoft.entra.conditionalaccessp  Block Legacy Auth   2                     active

# Get details
Get-TCMDrift | Select-Object -First 1 -ExpandProperty DriftedProperties

# propertyName    currentValue    desiredValue
# ------------    ------------    ------------
# DomainType      InternalRelay   Authoritative
```

## Step 8: Check Your Quota

```powershell
Get-TCMQuota

# === TCM Quota Dashboard ===
#
#   Monitors:            1 / 30     (3.3%)
#   Daily Resources:     168 / 800  (21%)
#   Snapshot Jobs:       1 / 12     (8.3%)
#   Snapshot Resources:  ~13 / 20,000 (visible jobs only)
```

## Step 9: Generate an HTML Report

```powershell
# Generate a drift report and open it in your browser
Export-TCMDriftReport -Open

# Or save to a specific path
Export-TCMDriftReport -OutputPath "./reports/drift-report.html"
```

The report shows a full dashboard: monitor status, quota usage with progress bars, active drifts with property-level detail (expected vs actual), baseline resource inventory, and **deep links to the relevant admin portal** (Entra, Exchange, Teams) for each resource type.

Works even with zero drifts — use it as a status dashboard.

## Step 10 (Optional): Bridge to Maester

If you use [Maester](https://maester.dev/) for M365 security testing:

```powershell
# Install Maester if you haven't already
Install-Module Maester -Scope CurrentUser -Force

# Create a Maester test folder and install default tests
mkdir maester-tests
cd maester-tests
Install-MaesterTests

# Sync TCM drifts into Maester's drift folder
# This also sets the environment variable MT.1060 needs for discovery
Sync-TCMDriftToMaester -OutputPath './Maester/Drift'

# Connect with Maester's required scopes
Connect-Maester

# Run just the drift tests
Invoke-Maester -Path './Maester/Drift/'

# Or run ALL Maester tests (400+ security checks + drift)
Invoke-Maester
```

**How it works:**
1. `Sync-TCMDriftToMaester` writes `baseline.json` + `current.json` into `./Maester/Drift/TCM-<MonitorName>/`
2. It sets the `$env:MAESTER_FOLDER_DRIFT` environment variable that MT.1060 needs
3. Maester's MT.1060 test auto-discovers drift suites and compares baseline vs current
4. If TCM detected drift → Maester test **fails** with property-level detail in Maester's HTML report
5. If no drift → Maester test **passes**

Zero Maester modifications needed. The sync is **not automatic** — run `Sync-TCMDriftToMaester` before `Invoke-Maester` to get fresh data.

> **Note:** The HTML report (`Export-TCMDriftReport`) and Maester integration (`Sync-TCMDriftToMaester`) are independent. Use one or both depending on your workflow.

No drifts yet? That's good — it means your tenant config hasn't changed since the snapshot. To test the integration, modify an existing Named Location or CA policy in the Entra portal, wait for the next 6-hour TCM cycle, then re-sync.

---

## Common Workflows

### Quick Health Check
```powershell
Test-TCMConnection      # Am I connected?
Get-TCMQuota            # What's my usage?
Get-TCMDrift            # Any active drifts?
Export-TCMDriftReport -Open   # Full HTML dashboard
```

### Daily Review (Maester + EasyTCM)
```powershell
Connect-MgGraph -Scopes 'Policy.Read.All','Organization.Read.All'
Import-Module EasyTCM
Sync-TCMDriftToMaester -OutputPath 'D:\maester-tests\Maester\Drift'
cd D:\maester-tests
Connect-Maester
Invoke-Maester
```

### Monitor a New Workload
```powershell
New-TCMSnapshot -DisplayName "Teams baseline" -Workloads Teams -Wait |
    Get-TCMSnapshot -IncludeContent |
    ConvertTo-TCMBaseline |
    New-TCMMonitor -DisplayName "Teams-only Monitor"
```

> **Tip:** You rarely need `-Workloads`. The default is to snapshot everything.
> Use it only when you want a monitor scoped to a single workload.

### Audit All Monitors
```powershell
Get-TCMMonitor | Format-Table displayName, status, monitorRunFrequencyInHours, createdDateTime
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Initialize-TCM` fails | Ensure you have Application Admin + Security Admin roles, or Global Admin |
| Snapshot stuck in "running" | TCM processes asynchronously. Wait a few minutes, or check errors: `(Get-TCMSnapshot -Id $id).errorDetails` |
| No drifts after creating monitor | Monitors run at fixed 6h intervals (6 AM, 12 PM, 6 PM, 12 AM UTC). Check cycle status with `Get-TCMMonitoringResult -Last 1`. |
| Can't tell if monitor is running | `Get-TCMMonitoringResult` shows cycle timing, status, and drift counts. If empty, the first cycle hasn't run yet. |
| New settings not detected as drift | TCM only monitors changes to resources that existed in the baseline. New tenant additions are **not** detected. |
| `Test-TCMConnection` shows `TCMApiReachable: False` | Permissions may take a few minutes to propagate after `Initialize-TCM`. Ensure you connected with Graph scopes like `Policy.Read.All`, `Organization.Read.All`, etc. |
| Quota exceeded | Use `Get-TCMQuota` to see usage. Reduce resources per monitor or delete unused monitors/snapshots. |

---

## Next Steps

- Read the [full cmdlet reference](../README.md#-core-cmdlets)
- Explore [baseline templates](../templates/) for CIS/CISA standards
- Learn about [the Maester bridge](#step-9-optional-bridge-to-maester)
- Check the [product vision and roadmap](../docs/VISION.md)
