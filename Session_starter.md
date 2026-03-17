# 🧠 AI Session Starter: EasyTCM (UTCM)

*Project memory file for AI assistant session continuity. Auto-referenced by custom instructions.*

---

## 📘 Project Context
**Project:** EasyTCM
**Repo Name:** UTCM
**Type:** PowerShell Module — Microsoft 365 Tenant Configuration Management
**Purpose:** Simplify Microsoft's Tenant Configuration Management (TCM) Graph beta APIs into an accessible PowerShell module — the "EasyPIM for TCM". Provides cmdlets for setup, snapshots, monitors, drift detection, reporting, and remediation guidance across Entra, Exchange, Intune, and Teams.
**Status:** ✅ v0.1.0 validated on live tenant — monitor active, awaiting first drift cycle
**GitHub:** https://github.com/kayasax/EasyTCM
**North Star:** TCM as Maester's drift detection backend (Sync-TCMDriftToMaester)
**Author:** Loïc MICHEL ([kayasax](https://github.com/kayasax))
**License:** MIT

**Core Technologies:**
- PowerShell 5.1+ / 7.0+ (cross-platform)
- Microsoft Graph Beta API (TCM endpoints)
- Microsoft.Graph.Authentication module
- Pester (testing)

**Available AI Capabilities:**
- 🔧 MCP Servers: Microsoft Docs MCP for TCM/Graph API reference
- 📚 Documentation: TCM API docs at `learn.microsoft.com/graph/unified-tenant-configuration-management-concept-overview`
- 🔍 Tools: GitHub MCP for repo management

---

## 🎯 Current State
**Build Status:** ✅ v0.1.0 — 14 cmdlets + 3 private helpers, validated on live tenant
**Key Achievement:** Full end-to-end pipeline works: snapshot → baseline → monitor → quota. Monitor is **active** on live tenant.
**Active Issue:** Wait for first drift cycle (~6h), then validate Get-TCMDrift + Sync-TCMDriftToMaester
**AI Enhancement:** Session configured with MCP server awareness for Microsoft docs

**Architecture Highlights:**
- PowerShell module following EasyPIM patterns (cmdlet-per-operation, JSON configs)
- TCM API covers 4 workloads: Entra (10 types), Exchange (18), Intune (1), Teams (9) = 38 total
- Defender and Purview workloads **removed** — ALL their types rejected by API (2026-03)
- Key innovation: Snapshot-to-Baseline converter (nobody else does this)
- Drift → Maester bridge via MT.1060 (merged in Maester v2.0+, Aug 2025)
- Quota management built-in with profiles: SecurityCritical (default), Recommended, Full

---

## 🧠 Technical Memory

**Critical Discoveries:**
- TCM is in **public preview** (beta Graph API) — ideal timing for community tooling
- TCM requires a dedicated service principal (AppId: `03b07b79-c5bc-4b5e-9bfa-13acf4a99998`)
- Two auth layers: (1) authenticate to Graph, (2) TCM SP impersonates calls to workload endpoints
- TCM schema is M365DSC-derived — resource types from the TCM schema store at `json.schemastore.org/utcm-monitor.json`
- Monitors run at **fixed 6-hour intervals** (6 AM, 12 PM, 6 PM, 12 AM UTC) — not configurable
- Baseline update **deletes all existing drifts** for that monitor
- Fixed drifts auto-deleted after 30 days
- Snapshot jobs evicted from API once 12 job limit reached (FIFO, not strictly 7-day expiry)
- **Monitor baseline API requires PascalCase keys** (DisplayName, ResourceType, Properties) — different from camelCase in snapshot responses
- **Invoke-MgGraphRequest returns OrderedDictionary** (hashtable), but JSON roundtrip creates PSCustomObject — code must handle both
- `Exchange.ManageAsApp` is NOT a valid Graph app role
- Defender and Purview workloads: ALL resource types rejected by API as of 2026-03

**Validated on Live Tenant (2026-03-17):**
- Tenant: `9b08d26c-2c4e-45c8-9313-b700c2ee6e3d` (loic@yespapa.eu)
- TCM SP ObjectId: `d21a1fee-ed53-4c44-aa2e-453a6f007849`
- Active monitor: `eca21d95-bee5-414d-b15e-1328d79f1b7d` (15 resources, SecurityCritical)
- Snapshot status: `partiallySuccessful` (38 types requested, some Exchange auth issues)
- Quota: 1/30 monitors, 60/800 daily resources (7.5%)

**Competitive Landscape:**
- **Maester** (805★) — Pester-based security testing. MT.1060 drift testing merged Aug 2025. TCM solves server-side state management.
- **EasyPIM** (221★) — PIM-only scope, excellent UX model to follow. Same author (kayasax).
- **M365DSC** — Full desired-state config, too heavy for monitoring-only use cases.
- **EntraExporter** — Export-only, no monitoring or drift detection.
- Nobody has built a PowerShell wrapper for TCM APIs yet.

**API Limits (Critical):**
| Resource | Limit |
|----------|-------|
| Monitors per tenant | 30 |
| Monitor frequency | Fixed 6 hours (4 cycles/day) |
| Monitored resources/day | 800 across all monitors |
| Snapshot resources/month | 20,000 cumulative |
| Visible snapshot jobs | 12 max |
| Snapshot retention | 7 days |
| Fixed drift retention | 30 days after resolved |

**Known Constraints:**
- TCM is beta — API may change before GA
- Some workloads (Exchange) require additional RBAC beyond Graph permissions
- Monitor baseline updates are destructive (delete all prior drifts)

---

## 🚀 Recent Achievements
| Date | Achievement |
|------|-------------|
| 2026-03-17 | ✅ Project initialized with session continuity infrastructure |
| 2026-03-17 | ✅ Deep research: TCM APIs, Maester, EasyPIM, M365DSC landscape analysis |
| 2026-03-17 | ✅ Feature gap analysis — identified 7 major opportunity areas |
| 2026-03-17 | ✅ MVP scope and priority defined (P0–P3) |
| 2026-03-17 | ✅ GitHub repository created (kayasax/EasyTCM) |
| 2026-03-17 | ✅ v0.1.0 MVP shipped — 14 cmdlets across setup, snapshot, monitor, drift, Maester bridge |
| 2026-03-17 | ✅ GitHub Actions CI (PSScriptAnalyzer + Pester) + PSGallery publish workflow |
| 2026-03-17 | ✅ Full product launch kit: vision doc, getting started guide, social media copy, issue templates |
| 2026-03-17 | ✅ CONTRIBUTING.md, CHANGELOG.md, PR templates, bug/feature/template issue templates |
| 2026-03-17 | ✅ Live tenant validation: snapshot (38 types), baseline (15 SecurityCritical), monitor ACTIVE |
| 2026-03-17 | ✅ Fixed: PascalCase API keys, PSCustomObject/.Keys, hashtable .Count, Defender/Purview removed |
| 2026-03-17 | ✅ Quota dashboard fixed (single-hashtable .Count bug) |

---

## 📋 Active Priorities

### ✅ DONE — v0.1.0 Foundation
- [x] ✅ Market analysis and feature gap identification
- [x] ✅ README, vision doc, getting started guide
- [x] ✅ GitHub repository + CI/CD workflows
- [x] ✅ 14 cmdlets: Initialize-TCM, Test-TCMConnection, New/Get/Remove-TCMSnapshot, ConvertTo-TCMBaseline, New/Get/Update/Remove-TCMMonitor, Get-TCMDrift, Get-TCMMonitoringResult, Get-TCMQuota, Sync-TCMDriftToMaester
- [x] ✅ Pester unit tests
- [x] ✅ Launch kit (blog, Twitter thread, LinkedIn, Reddit, Maester community post, YouTube script)

### 🎯 NOW — Validate Drifts & Ship (v0.2.0)
- [x] ✅ VALIDATED: Initialize-TCM, Test-TCMConnection, New-TCMSnapshot, Get-TCMSnapshot, ConvertTo-TCMBaseline, New-TCMMonitor, Get-TCMMonitor, Get-TCMQuota
- [x] ✅ Fixed: PascalCase keys, PSCustomObject iteration, hashtable .Count, empty arrays, Exchange.ManageAsApp removal
- [x] ✅ Removed Defender + Purview workloads (all types rejected by API)
- [ ] ⏳ Wait for first drift cycle → validate Get-TCMDrift + Sync-TCMDriftToMaester
- [ ] 🔗 Test Maester integration end-to-end (install Maester, run Invoke-Maester after sync)
- [ ] 📊 `Export-TCMDriftReport` (HTML with admin portal deep links)
- [ ] 📚 First CIS/CISA baseline template
- [ ] 🚀 Publish to PSGallery
- [ ] 📣 Public launch: blog + social + Maester community

### 🔮 NEXT — Ecosystem (v0.3.0+)
- [ ] Teams webhook notifications
- [ ] `Repair-TCMDrift` (remediation scripts)
- [ ] `Compare-TCMTenant` (multi-tenant diff)
- [ ] Multi-cloud support (GCC, China, Germany)
- [ ] EntraExporter integration

---

## 🔧 Development Environment
**Common Commands:**
- `Import-Module .\EasyTCM\EasyTCM.psd1` — Load module in dev
- `Invoke-Pester .\tests\` — Run test suite
- `Connect-MgGraph -Scopes 'Policy.Read.All','RoleManagement.Read.All','Organization.Read.All','DeviceManagementConfiguration.Read.All'` — Auth to Graph for TCM
- `Connect-MgGraph -UseDeviceCode ...` — Use device code flow from VS Code terminal

**Key Files:**
- `EasyTCM/EasyTCM.psd1` — Module manifest
- `EasyTCM/EasyTCM.psm1` — Module loader
- `EasyTCM/Public/` — Public cmdlets
- `EasyTCM/Private/` — Internal helper functions
- `tests/` — Pester tests
- `templates/` — Baseline templates (CIS, CISA, etc.)

**Setup Requirements:**
1. PowerShell 5.1+ or 7.0+
2. `Microsoft.Graph.Authentication` module
3. Entra ID tenant with privileges to create service principals
4. TCM service principal registered (`03b07b79-c5bc-4b5e-9bfa-13acf4a99998`)

**AI Tools:**
- Microsoft Docs MCP — TCM API reference and workload-specific resource schemas
- GitHub MCP — Repository management and issue tracking

---

*This file serves as persistent project memory for enhanced AI assistant session continuity with MCP server integration.*