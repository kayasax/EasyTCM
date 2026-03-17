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
    'ConfigurationMonitoring.ReadWrite.All'  # To manage monitors and snapshots
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

## Step 4: Snapshot Your Current Configuration

```powershell
# Take a snapshot of your entire tenant
$snapshot = New-TCMSnapshot -DisplayName "My first snapshot" -Wait

# The -Wait flag polls until the snapshot completes
# Output:
# No workloads specified — snapshotting all workloads.
# Creating snapshot 'My first snapshot' with 52 resource types...
#   Status: running — waiting 10s...
#   Status: running — waiting 10s...
# Snapshot completed successfully.
```

## Step 5: Convert Snapshot to Baseline (The Magic Step)

This is what makes EasyTCM unique — take your **current** config and use it as the **desired** state:

```powershell
# Download the snapshot content and convert to baseline
$snapshotWithContent = Get-TCMSnapshot -Id $snapshot.id -IncludeContent
$baseline = ConvertTo-TCMBaseline -SnapshotContent $snapshotWithContent.snapshotContent

# Output:
# Converted 42 resources into baseline.
```

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

## Step 9 (Optional): Bridge to Maester

If you use [Maester](https://maester.dev/) v2.0+ for M365 security testing:

```powershell
# Sync TCM drifts into Maester's drift folder — MT.1060 picks them up natively
Sync-TCMDriftToMaester

# Output:
# 🔗 Syncing TCM drifts to Maester format...
#   ⚠️ Entra Baseline Monitor: 2 drifts across 42 resources
#
# ⚠️ 2 active drifts synced across 1 monitors.
#    Run Invoke-Maester — MT.1060 will pick up the TCM drift suites automatically.

# Now run Maester normally — MT.1060 auto-discovers the TCM drift suites
Invoke-Maester
```

No Maester modifications needed. MT.1060 discovers any subfolder containing `baseline.json` + `current.json`.

---

## Common Workflows

### Quick Health Check
```powershell
Test-TCMConnection      # Am I connected?
Get-TCMQuota            # What's my usage?
Get-TCMDrift            # Any active drifts?
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
| No drifts after creating monitor | Monitors run at fixed 6h intervals (6 AM, 12 PM, 6 PM, 12 AM GMT). Wait for the next cycle. |
| `Test-TCMConnection` shows `TCMApiReachable: False` | Permissions may take a few minutes to propagate after `Initialize-TCM`. Also ensure you connected with `ConfigurationMonitoring.ReadWrite.All` scope. |
| Quota exceeded | Use `Get-TCMQuota` to see usage. Reduce resources per monitor or delete unused monitors/snapshots. |

---

## Next Steps

- Read the [full cmdlet reference](../README.md#-core-cmdlets)
- Explore [baseline templates](../templates/) for CIS/CISA standards
- Learn about [the Maester bridge](../docs/MAESTER-BRIDGE.md)
- Check the [product vision and roadmap](../docs/VISION.md)
