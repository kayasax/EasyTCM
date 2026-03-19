---
layout: default
title: "Continuous Monitoring Guide — EasyTCM"
---

# 🔄 Continuous Monitoring Guide

**The complete lifecycle: setup → daily checks → rebaselining → automation.**

EasyTCM provides three "easy button" cmdlets that cover the entire monitoring lifecycle. No deep TCM knowledge required.

---

## The Lifecycle

```
┌──────────────────────┐
│  Start-TCMMonitoring │  ← One-time setup (5 minutes)
│  Guided wizard       │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│    Watch-TCMDrift    │  ← Daily check (30 seconds)
│  Console / Report /  │
│  Maester             │
└──────────┬───────────┘
           │
     Drift detected?
     ┌─────┴─────┐
     │           │
   No ✅      Yes ⚠️
     │           │
     │     Investigate
     │           │
     │     Approved change?
     │     ┌─────┴─────┐
     │     │           │
     │   Yes         No 🚨
     │     │        Remediate!
     │     ▼
     │  ┌──────────────────────┐
     │  │  Update-TCMBaseline  │  ← Accept new state
     │  │  Rebaseline          │
     │  └──────────┬───────────┘
     │             │
     └──────►──────┘
              │
        Continue monitoring
```

---

## Step 1: Initial Setup

### The One-Command Way

```powershell
Install-Module EasyTCM -Scope CurrentUser
Start-TCMMonitoring
```

`Start-TCMMonitoring` handles everything:

```
╔══════════════════════════════════════════════════════╗
║         EasyTCM — Start Monitoring Setup             ║
╚══════════════════════════════════════════════════════╝

[ 1/5 ] Checking Microsoft Graph connection...
  Connected as admin@contoso.com to tenant abc123...

[ 2/5 ] Setting up TCM service principal and permissions...
  TCM service principal is ready.

[ 3/5 ] Checking for existing monitors...

[ 4/5 ] Taking a snapshot of your tenant (Recommended profile)...
  Converting snapshot to baseline...

[ 5/5 ] Creating monitor...

╔══════════════════════════════════════════════════════╗
║         ✅ Monitoring is now active!                  ║
╚══════════════════════════════════════════════════════╝

  Monitor : EasyTCM Recommended
  Profile : Recommended (28 resources)
  Schedule: TCM checks every 6 hours automatically
```

### Choosing a Profile

| Profile | Best For | Quota Impact |
|---------|----------|-------------|
| **Recommended** (default) | Most tenants — broad coverage, quota-safe | ~10-50% of daily limit |
| **SecurityCritical** | Strict quota or security-only focus | ~5-15% of daily limit |

```powershell
# Security-focused only
Start-TCMMonitoring -Profile SecurityCritical

# Already ran Initialize-TCM before? Skip that step
Start-TCMMonitoring -SkipInitialize
```

---

## Step 2: Daily Drift Checks

### Quick Console Check (30 seconds)

```powershell
Watch-TCMDrift
```

Shows a color-coded summary: green (no drift) or yellow (drift detected) with resource details.

### HTML Report (for auditors, managers, compliance)

```powershell
Watch-TCMDrift -Report
```

Generates an HTML dashboard with:
- Monitor status and quota usage (progress bars)
- Active drifts grouped by workload with property-level diffs
- Admin portal deep links for each resource type (click to remediate)
- Baseline inventory summary

### Maester Integration (for security teams)

```powershell
Watch-TCMDrift -Maester
```

Syncs drift data to Maester test format and runs `Invoke-Maester`. Results appear in Maester's HTML report alongside the 400+ built-in security checks.

### Finding Untracked Resources

TCM only monitors resources in the baseline. New CA policies or deleted transport rules won't appear as drift. Add `-CompareBaseline` to catch them:

```powershell
Watch-TCMDrift -CompareBaseline
```

Results are cached for 1 hour (uses a snapshot, which counts against quota).

---

## Step 3: Investigating Drift

When drift is detected, ask yourself:

| Question | If Yes | If No |
|----------|--------|-------|
| Was this an **approved change**? | Update the baseline | Investigate further |
| Was this change **expected** (rollout, migration)? | Update the baseline | This may be unauthorized |
| Does the change **weaken security**? | Remediate immediately | May still need review |

### Getting Details

```powershell
# Pipeline: get full drift objects
$drifts = Watch-TCMDrift -PassThru

# Filter to security-critical types
$drifts | Where-Object { $_.ResourceType -match 'conditionalaccesspolicy|authenticationmethod' }

# Full HTML report for documentation
Watch-TCMDrift -Report
```

---

## Step 4: Updating the Baseline

After **confirmed, approved changes**, accept the new tenant state:

```powershell
Update-TCMBaseline
```

This:
1. Shows current active drift (so you can review one last time)
2. Takes a fresh snapshot
3. Converts it to a baseline with the same profile
4. Updates the monitor
5. Clears all previous drift records

```
🔄 Update-TCMBaseline — Rebaseline after approved changes

Retrieving current monitor...
  Monitor: EasyTCM Recommended
  Profile: Recommended

  ⚠️  3 active drift(s) that will be cleared:
    • conditionalaccesspolicy — Block Legacy Auth (1 changes)
    • namedlocation — Corporate Network (1 changes)
    • transportrule — External Email Warning (2 changes)

Taking fresh snapshot...
Converting snapshot to baseline...
Updating monitor baseline...

✅ Baseline updated successfully!
   28 resources now monitored with 'Recommended' profile.
   All previous drift records have been cleared.

   Next: Watch-TCMDrift to verify clean state.
```

### When to Rebaseline

✅ **Do rebaseline when:**
- You deployed approved policy changes
- Onboarded a new service that adds resources
- Watch-TCMDrift confirms only expected drift
- Post-migration configuration stabilization

❌ **Do NOT rebaseline when:**
- You see unexpected drift — investigate first!
- Before reviewing current drift with Watch-TCMDrift
- As a way to "make drift go away" without understanding it

---

## Automation Ideas

### Scheduled Daily Report (Task Scheduler / Cron)

```powershell
# daily-drift-check.ps1
Connect-MgGraph -Identity  # Use managed identity or certificate
Import-Module EasyTCM
Watch-TCMDrift -Report
```

### CI/CD Pipeline Integration

```yaml
# GitHub Actions example
- name: Check M365 drift
  run: |
    Install-Module EasyTCM -Force -Scope CurrentUser
    Connect-MgGraph -ClientId ${{ secrets.APP_ID }} -TenantId ${{ secrets.TENANT_ID }} -CertificateThumbprint ${{ secrets.CERT_THUMB }}
    $drifts = Watch-TCMDrift -PassThru
    if ($drifts.Count -gt 0) {
      Write-Error "❌ $($drifts.Count) active drift(s) detected!"
      exit 1
    }
```

### Teams Notification (coming soon)

Planned for a future release — webhook-based alerts when new drift is detected.

---

## Cmdlet Quick Reference

| Command | Purpose | When |
|---------|---------|------|
| `Start-TCMMonitoring` | Guided setup wizard | First time only |
| `Watch-TCMDrift` | Console drift summary | Daily |
| `Watch-TCMDrift -Report` | HTML dashboard | For auditors/reports |
| `Watch-TCMDrift -Maester` | Maester test results | Security workflows |
| `Watch-TCMDrift -CompareBaseline` | Find untracked resources | Weekly |
| `Update-TCMBaseline` | Accept approved changes | After confirmed drift |
| `Get-TCMQuota` | Check API quota usage | When needed |
| `Compare-TCMBaseline -Detailed` | Deep resource comparison | Investigation |

---

## [← Maester Integration](maester-integration)
## [← Back to Home](.)
