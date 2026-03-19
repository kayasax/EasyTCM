---
layout: default
title: "EasyTCM — Stop Tenant Drift Before It Becomes a Breach"
---

# 🛡️ EasyTCM

**The missing PowerShell layer between Microsoft's TCM APIs and the 200,000+ M365 admins who need continuous configuration monitoring.**

From the creator of [EasyPIM](https://github.com/kayasax/EasyPIM) — the same philosophy applied to Microsoft's brand-new Tenant Configuration Management APIs.

[![PSGallery](https://img.shields.io/powershellgallery/v/EasyTCM?label=PSGallery&logo=powershell&color=blue)](https://www.powershellgallery.com/packages/EasyTCM)
[![Downloads](https://img.shields.io/powershellgallery/dt/EasyTCM?label=Downloads&color=green)](https://www.powershellgallery.com/packages/EasyTCM)
[![Stars](https://img.shields.io/github/stars/kayasax/EasyTCM?style=social)](https://github.com/kayasax/EasyTCM)

---

## The Problem: Every M365 Tenant Drifts

Someone changes a Conditional Access policy. A transport rule gets modified. A Teams federation setting shifts. An authentication method is disabled.

**You don't know until something breaks — or fails an audit.**

Configuration drift is one of the most common causes of security incidents in Microsoft 365:

- 🔓 **A Conditional Access exclusion added "temporarily"** — and forgotten for 6 months
- 📧 **An anti-phishing rule disabled during troubleshooting** — never re-enabled
- 🔑 **Authentication methods changed** — weakening MFA without anyone noticing
- 🌐 **Named locations modified** — opening network access from unintended regions

Without continuous monitoring, you're flying blind.

---

## The Solution: Tenant Configuration Management (TCM)

Microsoft shipped the [TCM APIs](https://learn.microsoft.com/en-us/graph/unified-tenant-configuration-management-concept-overview) (public preview) to solve this. TCM provides:

- **Server-side monitoring** — checks your config every 6 hours, automatically
- **6 workloads** — Entra, Exchange, Intune, Teams, Defender, Purview (62 resource types)
- **Property-level drift detection** — tells you exactly what changed, from what, to what
- **Baseline comparison** — compare current state against your known-good configuration

**But the raw API is complex.** Dual-layer authentication. Hand-crafted JSON baselines. Zero reporting. Strict quotas that are easy to blow.

**EasyTCM makes it accessible.**

---

## How EasyTCM Works

### One Command to Start

```powershell
Install-Module EasyTCM
Start-TCMMonitoring
```

That's it. `Start-TCMMonitoring` is a guided wizard that handles everything:

1. ✅ Connects to Microsoft Graph
2. ✅ Creates the TCM service principal and grants permissions
3. ✅ Takes a snapshot of your current tenant configuration
4. ✅ Converts it to a security-focused baseline
5. ✅ Creates a monitor that checks every 6 hours

### One Command to Check

```powershell
Watch-TCMDrift
```

```
🔍 Checking for configuration drift...

  ⚠️  3 active drift(s) detected!

  conditionalaccesspolicy (2):
    • Block Legacy Auth — 1 changed property
      state: enabled → disabled
    • Require MFA for Admins — 2 changed properties
      excludeUsers: [] → ["user@contoso.com"]
      sessionControls: {...} → {...}

  namedlocation (1):
    • Corporate Network — 1 changed property
      ipRanges: ["10.0.0.0/8"] → ["10.0.0.0/8","192.168.0.0/16"]
```

### One Command to Rebaseline

After approved changes, accept the new state:

```powershell
Update-TCMBaseline
```

---

## The Architecture

```
┌─────────────────────────────────────────────────┐
│                Microsoft 365 Tenant              │
│  Entra · Exchange · Intune · Teams · Compliance  │
└──────────────────┬──────────────────────────────┘
                   │
        TCM checks every 6 hours
                   │
┌──────────────────▼──────────────────────────────┐
│          TCM Service (Server-Side)               │
│  • Stores baselines                              │
│  • Runs monitoring cycles                        │
│  • Detects property-level drift                  │
│  • Tracks drift until resolved                   │
└──────────────────┬──────────────────────────────┘
                   │
            EasyTCM cmdlets
                   │
┌──────────────────▼──────────────────────────────┐
│              Your Workflow                        │
│                                                  │
│  Watch-TCMDrift           → Console summary      │
│  Watch-TCMDrift -Report   → HTML dashboard       │
│  Watch-TCMDrift -Maester  → Maester test suite   │
│  Update-TCMBaseline       → Accept new state     │
└─────────────────────────────────────────────────┘
```

---

## Why Monitoring Profiles Matter

TCM has a strict quota: **800 monitored resources per day** across all monitors. Each monitor runs 4 times/day (every 6 hours), so you can realistically monitor **~200 resource instances**.

A typical tenant has 300-500 resources. Monitoring everything **will blow your quota**.

EasyTCM solves this with **monitoring profiles** in `ConvertTo-TCMBaseline`:

| Profile | Resource Types | Typical Daily Cost | Coverage |
|---------|---------------|-------------------|----------|
| **SecurityCritical** (default) | ~16 | 80-120 / 800 | CA policies, auth methods, mail security, federation |
| **Recommended** | ~30 | 200-400 / 800 | Above + roles, compliance, device policies |
| **Full** | ~52 | ⚠️ 400-2000+ / 800 | Everything — will likely exceed quota |

**SecurityCritical covers 80% of the attack surface in ~15% of the quota.** That's the sweet spot.

```powershell
# Default — quota-safe, covers what matters
Start-TCMMonitoring

# Broader coverage
Start-TCMMonitoring -Profile Recommended
```

---

## [Maester Integration →](maester-integration)

Turn TCM's server-side monitoring into Maester test results — the bridge both communities have been waiting for.

## [Continuous Monitoring Guide →](continuous-monitoring)

The complete lifecycle: setup, daily checks, rebaselining, and automation.

## [Cmdlet Reference →](https://github.com/kayasax/EasyTCM#-cmdlets--v020-15-shipped)

All 19 cmdlets with examples and parameter documentation.

---

## Get Started Now

```powershell
Install-Module EasyTCM -Scope CurrentUser
Start-TCMMonitoring
```

**⭐ [Star the repo on GitHub](https://github.com/kayasax/EasyTCM)** — feedback and contributions welcome!
