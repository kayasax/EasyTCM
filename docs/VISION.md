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

### Milestone 1: MVP (v0.1.0) — SHIPPED
- [x] 15 cmdlets covering setup, snapshots, monitors, drift, reporting, Maester bridge
- [x] Validated end-to-end against live tenant
- [x] Real drift detection confirmed (IpRanges change on Named Location)
- [x] Maester MT.1060 integration working
- [x] HTML drift reports with admin portal deep links
- [x] GitHub Actions CI + PSGallery publish workflow

### Milestone 2: Public Launch (v0.2.0)
- [ ] Published to PSGallery
- [ ] Blog post: "Introducing EasyTCM"
- [ ] CIS/CISA baseline templates
- [ ] Community announcements (Reddit, Maester, Twitter/X, LinkedIn)

### Milestone 3: Ecosystem (v0.3.0+)
- [ ] Teams webhook notifications
- [ ] Remediation script generation (`Repair-TCMDrift`)
- [ ] Multi-tenant comparison (`Compare-TCMTenant`)
- [ ] EntraExporter integration
- [ ] Community contributions

---

## Key Messages

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
| Microsoft ships their own PowerShell module | We move faster; community UX beats official SDK |
