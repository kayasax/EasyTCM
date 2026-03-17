# EasyTCM Launch Kit — Social Media & Communications

Ready-to-use copy for announcing EasyTCM across platforms.

---

## Blog Post Draft

### Title: "Introducing EasyTCM: The Missing PowerShell Layer for Microsoft 365 Tenant Configuration Monitoring"

**Hook:**
Microsoft just shipped the Tenant Configuration Management (TCM) APIs — giving M365 admins the ability to monitor configuration drift across Entra, Exchange, Intune, Teams, Defender, and Purview. But the raw API requires dual-layer authentication, hand-crafted JSON baselines, and offers zero reporting.

**We built EasyTCM to fix that.**

**The problem:**
Every M365 tenant drifts. Someone changes a Conditional Access policy. A transport rule gets modified. A Teams setting shifts. Without continuous monitoring, you don't know until something breaks — or fails an audit.

TCM (now in public preview) solves this with server-side monitoring that checks your config every 6 hours. But using the raw Graph beta API means:
- Setting up a dedicated service principal with complex permissions
- Hand-writing JSON baselines with hundreds of resource types
- Manually calling REST endpoints with no reporting
- Tracking strict API quotas (800 resources/day, 20k snapshots/month)

**The solution:**
EasyTCM wraps all of that into 14 PowerShell cmdlets:

```powershell
# One-time setup
Initialize-TCM -Workloads Entra, Exchange

# Snapshot → Baseline → Monitor (the magic flow)
New-TCMSnapshot -DisplayName "Current config" -Workloads Entra -Wait |
    ConvertTo-TCMBaseline |
    New-TCMMonitor -DisplayName "Entra Monitor"

# Check for drifts
Get-TCMDrift | Format-Table Workload, ResourceType, ResourceDisplay, Status

# Bridge to Maester
Sync-TCMDriftToMaester -OutputPath "./maester-tests/Custom/drift"
```

**The Maester Bridge — Our North Star:**
The Maester community (800+ stars) has been debating how to add drift detection for months. The core challenge? State management — where do you store baselines between test runs?

TCM solves this server-side. And `Sync-TCMDriftToMaester` bridges TCM's monitoring data into Maester's testing format. TCM as the monitoring backend, Maester as the reporting frontend.

**From the creator of EasyPIM** (220+ stars), which simplified PIM management for thousands of Azure admins. EasyTCM applies the same philosophy to the entire M365 tenant configuration.

**Get started:**
- GitHub: https://github.com/kayasax/EasyTCM
- PSGallery: `Install-Module EasyTCM`
- Docs: Getting Started guide in the repo

---

## Twitter/X Thread (10 tweets)

**Tweet 1 (Hook):**
🛡️ Introducing EasyTCM — the missing PowerShell layer for Microsoft 365 Tenant Configuration Management.

14 cmdlets. 6 workloads. Continuous drift detection.

From the creator of EasyPIM.

🧵👇

**Tweet 2 (Problem):**
Microsoft shipped TCM APIs (public preview) — server-side monitoring for Entra, Exchange, Intune, Teams, Defender, Purview.

But the raw Graph beta API requires:
• Dual-layer auth setup
• Hand-crafted JSON baselines
• Zero reporting
• Manual quota tracking

**Tweet 3 (Solution):**
EasyTCM wraps it all:

```
Initialize-TCM -Workloads Entra, Exchange
New-TCMSnapshot -Workloads Entra -Wait | ConvertTo-TCMBaseline | New-TCMMonitor -DisplayName "My Monitor"
```

From zero to continuous monitoring in 3 commands.

**Tweet 4 (Killer feature):**
The killer feature: ConvertTo-TCMBaseline

Nobody else does this. Take your CURRENT config, use it as your DESIRED state, and start monitoring drift — instantly.

No hand-crafting JSON. No guessing resource schemas.

Snap → Baseline → Monitor.

**Tweet 5 (Maester bridge):**
🔗 The Maester Bridge — our north star.

@Maester365 (800+ ⭐) has been debating drift detection for months. The blocker? State management.

TCM stores baselines server-side. EasyTCM bridges TCM drifts into Maester test results.

Problem solved. Server-side.

**Tweet 6 (Quota):**
TCM has strict API limits that are easy to blow:
• 800 resources/day
• 20k snapshots/month
• 30 monitors max

Get-TCMQuota gives you a real-time dashboard so you never hit a wall.

**Tweet 7 (Workload coverage):**
6 workloads covered:
✅ Entra (CA policies, auth methods, admin units)
✅ Exchange (transport rules, anti-phishing, DKIM)
✅ Intune (compliance, config profiles)
✅ Teams (meeting, messaging, federation)
✅ Defender (safe links, safe attachments)
✅ Purview (sensitivity labels, retention)

**Tweet 8 (Author credibility):**
Built by @yourhandle — creator of @EasyPIM (220+ ⭐, 50+ cmdlets) that simplified PIM for thousands of Azure admins.

Same philosophy: take a powerful Microsoft API and make it accessible through simple PowerShell.

**Tweet 9 (Call to action):**
Get started in 5 minutes:

```
Install-Module EasyTCM
Connect-MgGraph
Initialize-TCM -Workloads Entra
```

📖 Full guide: [link to Getting Started]
⭐ GitHub: https://github.com/kayasax/EasyTCM

**Tweet 10 (Community):**
EasyTCM is open source (MIT) and we want your help:

🎯 Baseline templates for CIS/CISA standards
🐛 Bug reports from real-world testing
💡 Feature requests
🤝 PRs welcome

Let's make M365 configuration monitoring accessible to every admin. 🛡️

---

## LinkedIn Post

**Excited to announce EasyTCM** — a new open-source PowerShell module that simplifies Microsoft 365 Tenant Configuration Management.

🎯 **The problem:** M365 tenants drift from their intended configuration constantly. Conditional Access policies change. Exchange transport rules get modified. Teams settings shift. Without continuous monitoring, you don't know until an audit fails.

🚀 **The solution:** Microsoft shipped the TCM APIs (now in public preview) for server-side configuration monitoring across Entra, Exchange, Intune, Teams, Defender, and Purview. But the raw API is complex.

EasyTCM wraps it into 14 simple PowerShell cmdlets:
• `Initialize-TCM` — one command to set up everything
• `ConvertTo-TCMBaseline` — snapshot your current config and use it as your desired state
• `Get-TCMDrift` — see exactly what changed and when
• `Sync-TCMDriftToMaester` — bridge to the Maester security testing framework

🔗 **The Maester Bridge:** Maester (800+ stars) is the #1 community tool for M365 security testing. They've been working on drift detection, and the biggest challenge was state management. TCM solves this server-side, and EasyTCM bridges the two tools together.

From the creator of EasyPIM (220+ stars), which simplified Privileged Identity Management for the Azure admin community.

📦 Install: `Install-Module EasyTCM`
🔗 GitHub: https://github.com/kayasax/EasyTCM

Would love feedback from the M365 admin community!

#Microsoft365 #PowerShell #EntraID #Azure #SecurityEngineering #OpenSource

---

## Reddit Posts

### r/PowerShell

**Title:** EasyTCM — PowerShell module wrapping Microsoft's new Tenant Configuration Management APIs (TCM)

Microsoft just shipped TCM APIs in public preview for monitoring M365 tenant config drift server-side (Entra, Exchange, Intune, Teams, Defender, Purview). The raw Graph beta API is complex, so I built EasyTCM to simplify it into 14 cmdlets.

The killer feature: `ConvertTo-TCMBaseline` — snapshot your current config and convert it to a monitoring baseline in one pipeline.

Also built a bridge to Maester (`Sync-TCMDriftToMaester`) that converts TCM drifts into Maester test results — solving their state management challenge.

From the same author as EasyPIM.

GitHub: https://github.com/kayasax/EasyTCM

Feedback welcome!

### r/sysadmin

**Title:** New open-source tool: Monitor M365 configuration drift across Entra, Exchange, Teams, Intune, Defender, Purview

Tired of not knowing when someone changes a Conditional Access policy or Exchange transport rule?

Microsoft shipped TCM (Tenant Configuration Management) APIs that monitor your M365 config every 6 hours, server-side. But the raw API is complex.

I built EasyTCM (PowerShell module) to simplify it:
1. Snapshot your current config
2. Convert to a monitoring baseline
3. TCM checks every 6 hours and reports drift
4. (Optional) Bridge results to Maester for reporting

Free, open source, MIT licensed: https://github.com/kayasax/EasyTCM

---

## Maester Community Post

### GitHub Discussion (maester365/maester)

**Title:** TCM as Maester's drift detection backend — EasyTCM bridge

Hi team! Following up on the drift detection discussion from PR #995 and the great conversation about state management.

I've built **EasyTCM** — a PowerShell module wrapping Microsoft's new Tenant Configuration Management (TCM) APIs. TCM provides exactly what was being discussed:

- **Server-side baseline storage** (no local state management needed)
- **Automatic 6-hour monitoring cycles** (no cron/scheduler required)
- **Active drift tracking** with property-level details (expected vs actual)

The module includes `Sync-TCMDriftToMaester` which generates Maester-compatible drift suites:

```
tests/Custom/drift/
  TCM-EntraMonitor/
    baseline.json    # From TCM monitor baseline
    current.json     # Baseline + drift deltas applied
  TCM-Drift.Tests.ps1  # Auto-generated Pester test
```

This fits the pattern established in PR #995 — `baseline.json` + `current.json` in discoverable folders.

The key insight: **TCM handles the state management server-side**. Baselines are stored in the TCM service, monitors run automatically, and drifts are tracked until resolved. No blob storage, no git commits, no local state between runs.

Would love feedback on whether this integration approach aligns with where Maester is heading.

GitHub: https://github.com/kayasax/EasyTCM

---

## YouTube Short Script (3 minutes)

**[0:00-0:15] Hook:**
"Microsoft just shipped an API that monitors your M365 tenant configuration every 6 hours and tells you when something changes. But nobody can use it because it's too complex. I fixed that."

**[0:15-0:45] Problem:**
"Here's the raw TCM API. You need to create a service principal, grant dual-layer permissions, hand-craft JSON baselines with hundreds of resource types... and there's zero reporting. Most admins will never touch this."

**[0:45-1:15] Solution:**
"EasyTCM wraps it into PowerShell. Watch: Initialize-TCM sets up everything in one command. New-TCMSnapshot captures your current config. ConvertTo-TCMBaseline — this is the magic — turns your snapshot into the monitoring baseline. New-TCMMonitor starts watching. Done."

**[1:15-1:45] Drift:**
"Six hours later, Get-TCMDrift shows me exactly what changed. This conditional access policy was modified. This domain type changed from Authoritative to InternalRelay. Property-level detail."

**[1:45-2:15] Maester Bridge:**
"And if you use Maester — Sync-TCMDriftToMaester pushes all of this into Maester's test framework. TCM monitors server-side, Maester reports. It's the integration both communities have been waiting for."

**[2:15-2:45] Call to Action:**
"Install-Module EasyTCM. Link in description. Star the repo. And if you build a CIS or CISA baseline template, submit a PR — that's where the real community value is."

**[2:45-3:00] Outro:**
"From the creator of EasyPIM. Let's make M365 configuration monitoring accessible to every admin."
