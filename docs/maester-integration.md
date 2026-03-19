---
layout: default
title: "Maester Integration — EasyTCM"
---

# 🔗 Maester Integration

**Turn TCM's server-side monitoring into Maester test results — solving the drift state management problem.**

[Maester](https://maester.dev/) is the #1 community tool for Microsoft 365 security testing (800+ stars). The Maester community has been working on drift detection, and the biggest challenge was **state management** — where do you store baselines between test runs?

**TCM solves this server-side. EasyTCM bridges the two.**

---

## Why This Matters

| Challenge | Without EasyTCM | With EasyTCM |
|-----------|-----------------|--------------|
| **Baseline storage** | Local files, git commits, blob storage | TCM stores baselines server-side |
| **Monitoring schedule** | Cron jobs, scheduled tasks | TCM runs automatically every 6 hours |
| **Drift detection** | Client-side comparison scripts | TCM detects server-side, property-level |
| **Maester reporting** | Build your own tests | `Watch-TCMDrift -Maester` — one command |

---

## How It Works

```
TCM Service                    EasyTCM                     Maester
    │                             │                           │
    │  baseline + drift data      │                           │
    ├────────────────────────────►│                           │
    │                             │  Sync-TCMDriftToMaester   │
    │                             ├──────────────────────────►│
    │                             │  baseline.json            │
    │                             │  current.json             │
    │                             │  TCM-Drift.Tests.ps1      │
    │                             │                           │
    │                             │      Invoke-Maester       │
    │                             │◄──────────────────────────┤
    │                             │  HTML report with         │
    │                             │  pass/fail per resource   │
```

### What Gets Generated

When you run `Watch-TCMDrift -Maester`, EasyTCM:

1. **Fetches active drift** from TCM via `Get-TCMDrift`
2. **Generates test suites** per monitor in your Maester tests folder:

```
maester-tests/
  Drift/
    TCM-EasyTCM Recommended/
      baseline.json           ← Monitor's known-good state
      current.json            ← Baseline + drift deltas applied
      TCM-Drift.Tests.ps1     ← Auto-generated Pester tests
```

3. **Runs Invoke-Maester** on the drift folder
4. **Reports results** using `Add-MtTestResultDetail` with property-level markdown tables

### What the Maester Report Shows

Each drifted resource becomes a **failing test** with details:

```
❌ TCM Drift: conditionalaccesspolicy — Block Legacy Auth [2 drifted properties]

| Property | Baseline | Current |
|----------|----------|---------|
| state | enabled | disabled |
| excludeUsers | [] | ["user@contoso.com"] |
```

Clean resources show as **passing tests**.

---

## Setup

### One-Time: Set Your Maester Tests Path

```powershell
# Tell EasyTCM where your Maester tests live (persists across sessions)
[Environment]::SetEnvironmentVariable('MAESTER_TESTS_PATH', 'D:\maester-tests', 'User')
$env:MAESTER_TESTS_PATH = 'D:\maester-tests'
```

### Daily Workflow

```powershell
# Option 1: One command does everything
Watch-TCMDrift -Maester

# Option 2: Step by step
Sync-TCMDriftToMaester                             # Generate test files
Invoke-Maester -Path "$env:MAESTER_TESTS_PATH\Drift"  # Run drift tests only

# Option 3: Full Maester suite (drift + 400+ security checks)
Sync-TCMDriftToMaester
cd $env:MAESTER_TESTS_PATH
Invoke-Maester
```

### With Baseline Comparison (Catches New/Deleted Resources)

TCM drift detection only tracks **property changes** on existing resources. A new CA policy or a deleted transport rule won't appear as drift.

`-CompareBaseline` fills that gap:

```powershell
Watch-TCMDrift -Maester -CompareBaseline
```

This takes a snapshot (cached for 1 hour to save quota) and adds new/deleted resources to the Maester report.

---

## What Makes This Special

1. **Zero Maester modifications needed** — EasyTCM generates standard `.Tests.ps1` files that Maester discovers natively
2. **Server-side state** — No local baseline files to manage, no git commits to track, no blob storage to configure
3. **Automatic monitoring** — TCM checks every 6 hours whether you run Maester or not
4. **On-demand reporting** — Run `Watch-TCMDrift -Maester` whenever you want fresh results
5. **Complementary, not competing** — EasyTCM enhances Maester, it doesn't replace the 400+ existing security tests

---

## [← Back to Home](.)
## [Continuous Monitoring →](continuous-monitoring)
