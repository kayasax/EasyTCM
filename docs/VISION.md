# EasyTCM — Product Vision & Launch Plan

## The One-Liner

**EasyTCM is the missing PowerShell layer between Microsoft's new TCM APIs and the 200,000+ M365 admins who need continuous configuration monitoring without the complexity.**

---

## Vision Statement

Every M365 tenant drifts from its intended configuration. Microsoft shipped the TCM APIs to fix that — but wrapped them in raw REST calls, dual-layer authentication, hand-crafted JSON baselines, and zero reporting.

**EasyTCM makes TCM accessible to every M365 admin**, the same way EasyPIM made Privileged Identity Management accessible. One module. Simple cmdlets. Instant value.

Our **north star** is the Maester bridge: TCM detects drift server-side every 6 hours. Maester is the #1 community tool for M365 security testing. EasyTCM is the **glue** that turns TCM's server-side monitoring into Maester's drift engine — solving the #1 open problem that the Maester community debated for months (state management for drift detection).

---

## Target Personas

| Persona | Pain | EasyTCM Value |
|---------|------|---------------|
| **M365 Admin (Solo)** | "I don't know when someone changes a CA policy" | Snap → Monitor → Alert in 5 minutes |
| **Security Engineer** | "We need continuous compliance against CIS/CISA" | Pre-built baselines, HTML reports |
| **MSP / Consultant** | "I manage 50+ tenants, how do I track drift?" | Multi-tenant comparison, batch snapshots |
| **Maester User** | "Drift detection is stateless, where do I store baselines?" | TCM stores them server-side. Sync-TCMDriftToMaester bridges the gap |
| **DevOps / SRE** | "We need tenant config in CI/CD pipelines" | PSGallery module, GitHub Actions, JSON config |

---

## Competitive Positioning

```
                    Complexity
                        ↑
                        |
           M365DSC ●    |
          (full DSC)    |
                        |
     Raw TCM API ●      |
                        |
                        |    ● EasyTCM (sweet spot)
                        |
         Maester ●      |    ● EasyPIM (PIM only)
       (testing)        |
                        +—————————————————→ Scope
                   narrow              broad
```

EasyTCM sits in the **sweet spot**: broader than PIM-only tools, simpler than full DSC, and complementary to (not competing with) Maester.

---

## Launch Milestones

### Milestone 1: MVP (v0.1.0) ← WE ARE HERE
- [x] 14 cmdlets covering setup, snapshots, monitors, drift, Maester bridge
- [x] Module loads and exports correctly
- [x] Pester tests for module structure
- [ ] **Validate against a live tenant** ← FIRST THING TO DO
- [ ] Fix any API response format issues discovered during testing

### Milestone 2: Publish-Ready (v0.2.0)
- [ ] All cmdlets tested against live TCM API
- [ ] `ConvertTo-TCMBaseline` confirmed with real snapshot data
- [ ] `Sync-TCMDriftToMaester` generates valid Maester drift suites
- [ ] GitHub Actions CI (lint + test on push)
- [ ] PSGallery publish workflow
- [ ] Getting Started guide with real terminal screenshots

### Milestone 3: Public Launch (v0.3.0)
- [ ] Published to PSGallery
- [ ] Blog post: "Introducing EasyTCM"
- [ ] Twitter/X thread
- [ ] LinkedIn post
- [ ] Reddit: r/PowerShell, r/sysadmin, r/YOURM365
- [ ] Maester community: open discussion proposing TCM bridge
- [ ] YouTube short: 3-minute demo

### Milestone 4: Community Growth (v0.5.0+)
- [ ] CIS/CISA baseline templates
- [ ] HTML drift reports with admin portal deep links
- [ ] Teams webhook notifications
- [ ] EntraExporter integration
- [ ] Multi-tenant comparison
- [ ] Contribution from community

---

## What To Do RIGHT NOW

### Step 1: Validate the MVP (30 min)
```powershell
# Connect to a test tenant
Connect-MgGraph -Scopes 'Application.ReadWrite.All','AppRoleAssignment.ReadWrite.All','ConfigurationMonitoring.ReadWrite.All'

# Run Initialize-TCM — does the SP get created?
Initialize-TCM -TenantId $tenantId -Workloads Entra

# Test connection
Test-TCMConnection

# Take a snapshot
$snap = New-TCMSnapshot -DisplayName "First test" -Workloads Entra -Wait

# Look at the snapshot content
$snap = Get-TCMSnapshot -Id $snap.id -IncludeContent
$snap.snapshotContent | ConvertTo-Json -Depth 5 | Out-File ./first-snapshot.json

# Convert to baseline
$baseline = $snap | ConvertTo-TCMBaseline

# Create a monitor
New-TCMMonitor -DisplayName "Test Monitor" -Baseline $baseline

# Check quota
Get-TCMQuota

# Wait 6 hours... then check drifts
Get-TCMDrift
```

### Step 2: Fix What Breaks (1-2 hours)
The snapshot content format from the real API will likely differ from our assumptions. Adjust `ConvertTo-TCMBaseline` and `Sync-TCMDriftToMaester` based on actual data.

### Step 3: Record a Demo (30 min)
Screen-record the Step 1 workflow. This becomes:
- The README GIF
- The YouTube short
- The blog post screenshots

### Step 4: Publish to PSGallery
```powershell
Publish-Module -Path ./EasyTCM -NuGetApiKey $apiKey
```
(or use the GitHub Actions workflow we're about to create)

### Step 5: Announce
Post the blog + social using the launch kit materials below.

---

## Key Messages for All Communications

1. **"TCM is the future of M365 configuration management. EasyTCM makes it accessible today."**
2. **"Snap → Monitor → Report. Three steps to continuous tenant monitoring."**
3. **"The missing bridge between Microsoft's TCM API and the Maester community."**
4. **"From the creator of EasyPIM (200+ stars, 50+ cmdlets)."**

---

## Risk Register

| Risk | Mitigation |
|------|------------|
| TCM API changes before GA | Pin to known beta version; abstract API calls behind private helpers |
| Low adoption (TCM too new) | Piggyback on Maester's existing community via the bridge feature |
| Maester team rejects bridge approach | Bridge works standalone; no Maester dependency required |
| Snapshot content format differs from expectation | First priority: validate against real tenant |
| Microsoft ships their own PowerShell module | We move faster; community UX beats official SDK |
