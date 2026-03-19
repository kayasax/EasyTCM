# LinkedIn Post — EasyTCM v0.3.0 Launch

## Option A: Technical Storytelling (Recommended)

---

**Three commands. That's all it takes to monitor your entire Microsoft 365 tenant for configuration drift.**

```
Start-TCMMonitoring    # setup wizard
Watch-TCMDrift         # daily check
Update-TCMBaseline     # after approved changes
```

I just shipped v0.3.0 of EasyTCM — an open-source PowerShell module that wraps Microsoft's new Tenant Configuration Management (TCM) APIs.

📖 **The problem nobody talks about:**

Every M365 tenant drifts from its intended configuration. Someone adds a Conditional Access exclusion "temporarily." An anti-phishing rule gets disabled during troubleshooting. An authentication method changes without anyone noticing.

You don't know until something breaks — or fails an audit.

🛡️ **What TCM does (the Microsoft part):**

Microsoft shipped TCM APIs (public preview) that monitor your tenant config server-side every 6 hours across Entra, Exchange, Intune, Teams, and Security & Compliance — 62 resource types. Property-level drift detection with baseline comparison.

But the raw Graph beta API requires dual-layer authentication, hand-crafted JSON baselines, and offers zero reporting.

⚡ **What EasyTCM does (the community part):**

EasyTCM turns that complexity into 19 PowerShell cmdlets. v0.3.0 introduces three "easy button" commands:

→ `Start-TCMMonitoring` — A guided wizard that handles everything: Graph connection, service principal setup, snapshot, baseline conversion, and monitor creation. Zero to monitoring in one run.

→ `Watch-TCMDrift` — Your daily command. Console summary by default, `-Report` for an HTML dashboard with admin portal deep links, or `-Maester` to pipe results into the Maester security testing framework.

→ `Update-TCMBaseline` — After approved changes, take a fresh snapshot and update the baseline. Shows current drift for review before clearing.

🔗 **The Maester bridge — why it matters:**

Maester (maester.dev) is the #1 community tool for M365 security testing. Their community has been working on drift detection, and the biggest challenge was state management — where do you store baselines between runs?

TCM stores them server-side. `Watch-TCMDrift -Maester` bridges the two tools: TCM monitors, Maester reports. Zero Maester modifications needed.

📊 **Smart quota management:**

TCM limits you to 800 monitored resources/day. EasyTCM's monitoring profiles (SecurityCritical, Recommended) ensure you monitor what matters without blowing your quota. SecurityCritical covers 80% of the attack surface in ~15% of the quota.

Built in the same spirit as EasyPIM — take a powerful Microsoft API and make it accessible to every admin.

📦 `Install-Module EasyTCM`
📖 https://kayasax.github.io/EasyTCM/
⭐ https://github.com/kayasax/EasyTCM

#Microsoft365 #PowerShell #EntraID #Azure #CyberSecurity #OpenSource #TenantConfigurationManagement #Maester #ConfigurationDrift

---

## Option B: Shorter / Punchier

---

**"When did someone change that Conditional Access policy?"**

If you've ever asked that question, you need configuration drift monitoring.

I just released EasyTCM v0.3.0 — an open-source PowerShell module that wraps Microsoft's new TCM APIs into three simple commands:

```
Start-TCMMonitoring    # one-command setup wizard
Watch-TCMDrift         # daily check (console, HTML, or Maester)
Update-TCMBaseline     # rebaseline after approved changes
```

What it does:
✅ Monitors your M365 tenant configuration every 6 hours (server-side)
✅ Detects property-level changes across Entra, Exchange, Intune, Teams, Compliance
✅ HTML reports with admin portal deep links
✅ Bridges to Maester for security test integration
✅ Smart quota management — monitor what matters, not everything

19 cmdlets. 62 resource types. 6 workloads.

From the creator of EasyPIM.

📦 `Install-Module EasyTCM`
📖 https://kayasax.github.io/EasyTCM/
⭐ https://github.com/kayasax/EasyTCM

#Microsoft365 #PowerShell #EntraID #CyberSecurity #OpenSource

---

## Option C: Narrative / Personal Story

---

I built EasyPIM because PIM management through the Azure portal was painful. Thousands of admins agreed.

Now I'm tackling a bigger problem: **configuration drift in Microsoft 365**.

Microsoft just shipped the Tenant Configuration Management (TCM) APIs — server-side monitoring that checks your Entra, Exchange, Intune, Teams, and Compliance config every 6 hours. Powerful stuff.

But the raw API? Complex dual-layer auth. Hand-crafted JSON baselines. No reporting. Easy to blow strict API quotas.

Sound familiar? That's exactly the gap EasyPIM filled for PIM.

So I built EasyTCM, and today I'm shipping v0.3.0 with what I call the "easy buttons":

🟢 `Start-TCMMonitoring` — From zero to monitoring in one command. A guided wizard handles the entire setup.

🔍 `Watch-TCMDrift` — One command to check for drift. Console output, HTML reports, or Maester test results.

🔄 `Update-TCMBaseline` — After you approve changes, accept the new state and keep monitoring.

The Maester integration is what I'm most proud of. Maester (maester.dev) is the gold standard for M365 security testing, and their community has been working on drift detection. The challenge? Where to store baselines between test runs.

TCM stores them server-side. EasyTCM bridges TCM's monitoring into Maester's reporting. One command: `Watch-TCMDrift -Maester`.

19 cmdlets. 62 resource types. Free. Open source.

📦 Install: `Install-Module EasyTCM`
📖 Docs: https://kayasax.github.io/EasyTCM/
⭐ GitHub: https://github.com/kayasax/EasyTCM

Would love feedback from the community. What would you want to monitor first?

#Microsoft365 #PowerShell #EntraID #CyberSecurity #OpenSource
