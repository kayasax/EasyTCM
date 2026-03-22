# Baseline Templates

Pre-built templates that scope your TCM monitor to the resource types that matter for your use case. When a monitored config changes, TCM detects it within 6 hours.

> **EasyTCM watches the config. Maester/ScubaGear checks the rules.**
> Templates define *what to monitor*, not *how to evaluate*. Pair with Maester for compliance testing.

> **Severity labels:** Controls use **SHALL** (mandatory — must be configured, non-compliance is a security gap) and **SHOULD** (recommended — best practice, but legitimate exceptions may exist). These follow [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and align with CISA SCuBA terminology.

## Choosing a Template

| If you are… | Start with | Why |
|---|---|---|
| **Admin / SecOps** — watching for unauthorized changes | `EasyTCM-SecurityCritical` or `EasyTCM-Recommended` | Covers the resource types most likely to cause security exposure if changed |
| **Compliance** — aligning to CISA SCuBA / BOD 25-01 | `CISA-SCuBA-Entra`, `CISA-SCuBA-Exchange`, `CISA-SCuBA-Teams` | Maps directly to CISA control IDs for audit evidence |
| **Both** — drift + compliance coverage | Combine them (see below) | Merged resource types in a single monitor |

### Combining Templates

The `-Template` parameter accepts **multiple names**. Resource types are merged, so you get a single monitor covering both drift detection and compliance scope:

```powershell
# Drift + CISA Entra compliance in one monitor
ConvertTo-TCMBaseline -Template EasyTCM-SecurityCritical, CISA-SCuBA-Entra `
  -SnapshotId $id | New-TCMMonitor -DisplayName 'Drift + CISA Entra'

# Full CISA + recommended drift — maximum coverage
ConvertTo-TCMBaseline -Template EasyTCM-Recommended, CISA-SCuBA-Entra, CISA-SCuBA-Exchange, CISA-SCuBA-Teams `
  -SnapshotId $id | New-TCMMonitor -DisplayName 'Full Coverage'
```

> **Quota check:** Combined templates increase resource types. Run `Get-TCMQuota` after creating the monitor to confirm you stay within the 200-instance limit.

## Available Templates

### EasyTCM Profiles — Security-prioritized monitoring

| Template | Focus | Resource Types | Controls | Quota Impact |
|---|---|---|---|---|
| `easytcm-security-critical.json` | Identity + mail security + federation | 14 | 12 | Low |
| `easytcm-recommended.json` | SecurityCritical + org config, Teams, Intune, DLP, retention | 29 | 23 | Medium |

### CISA SCuBA — Compliance-aligned monitoring

| Template | Standard | Resource Types | Controls | BOD 25-01 |
|---|---|---|---|---|
| `cisa-scuba-entra.json` | CISA SCuBA — Entra ID | 6 | 18 | 12 |
| `cisa-scuba-exchange.json` | CISA SCuBA — Exchange Online | 12 | 14 | 7 |
| `cisa-scuba-teams.json` | CISA SCuBA — Teams | 5 | 9 | 4 |

## Quick Start

```powershell
# SecurityCritical monitor — default, low quota
New-TCMSnapshot -Wait | ConvertTo-TCMBaseline -Template EasyTCM-SecurityCritical | New-TCMMonitor

# Recommended monitor — broader coverage
New-TCMSnapshot -Workload Entra, Exchange, Teams -Wait `
  | ConvertTo-TCMBaseline -Template EasyTCM-Recommended `
  | New-TCMMonitor -DisplayName 'Recommended'

# CISA SCuBA scoped monitor
ConvertTo-TCMBaseline -Template CISA-SCuBA-Entra, CISA-SCuBA-Exchange, CISA-SCuBA-Teams `
  -SnapshotContent $snap | New-TCMMonitor -DisplayName 'CISA SCuBA'
```

---

## EasyTCM-SecurityCritical — 12 controls across 14 resource types

**Default profile.** High-priority resource types that create immediate security exposure if changed. Covers 80% of the attack surface: identity, mail security, and federation.

<details>
<summary>Controls and resource types</summary>

| Control | What TCM Monitors | Severity | Resource Types |
|---|---|---|---|
| SC.ENTRA.CA | Conditional Access policies | SHALL | conditionalaccesspolicy |
| SC.ENTRA.AUTHMETHOD | Authentication method policies | SHALL | authenticationmethodpolicy |
| SC.ENTRA.AUTHZ | Authorization policies | SHALL | authorizationpolicy |
| SC.ENTRA.XTENANT | Cross-tenant access policies | SHALL | crosstenantaccesspolicy, crosstenantaccesspolicyconfigurationpartner |
| SC.ENTRA.NAMEDLOC | Named location policies | SHALL | namedlocationpolicy |
| SC.EXO.ANTIPHISH | Anti-phishing policies and rules | SHALL | antiphishpolicy, antiphishrule |
| SC.EXO.TRANSPORT | Transport rules (mail flow) | SHALL | transportrule |
| SC.EXO.DKIM | DKIM signing configuration | SHALL | dkimsigningconfig |
| SC.EXO.SPAM | Content filter (anti-spam) | SHALL | hostedcontentfilterpolicy |
| SC.EXO.SAFELINKS | Safe Links policies | SHALL | safelinkspolicy |
| SC.EXO.SAFEATTACH | Safe Attachments policies | SHALL | safeattachmentpolicy |
| SC.TEAMS.FEDERATION | Teams federation configuration | SHALL | federationconfiguration |

</details>

## EasyTCM-Recommended — 23 controls across 29 resource types

**Balanced coverage.** Everything in SecurityCritical plus org config, mail connectors, Teams policies, Intune account protection, and Security & Compliance data protection.

> **Quota note:** May approach the 200 instances/run limit in tenants with many CA policies, transport rules, or Teams policies. Run `Get-TCMQuota` after creating the monitor.

<details>
<summary>Additional controls beyond SecurityCritical</summary>

| Control | What TCM Monitors | Severity | Resource Types |
|---|---|---|---|
| REC.EXO.ORGCONFIG | Exchange organization configuration | SHOULD | organizationconfig |
| REC.EXO.CONNECTORS | Mail connectors (inbound/outbound) | SHOULD | inboundconnector, outboundconnector |
| REC.EXO.OUTBOUNDSPAM | Outbound spam filter policy | SHOULD | hostedoutboundspamfilterpolicy |
| REC.EXO.MALWARE | Malware filter rules | SHOULD | malwarefilterrule |
| REC.TEAMS.MEETINGS | Meeting policies and configuration | SHOULD | meetingpolicy, meetingconfiguration |
| REC.TEAMS.MESSAGING | Messaging policies | SHOULD | messagingpolicy |
| REC.TEAMS.APPS | App permission policies | SHOULD | apppermissionpolicy |
| REC.INTUNE.ACCTPROT | Local admin group membership | SHOULD | accountprotectionlocalusergroupmembershippolicy |
| REC.SC.DLP | DLP compliance policies | SHOULD | dlpcompliancepolicy |
| REC.SC.RETENTION | Retention policies and rules | SHOULD | retentioncompliancepolicy, retentioncompliancerule |
| REC.SC.LABELS | Sensitivity label policies and tags | SHOULD | labelpolicy, compliancetag |

*Plus all 12 SecurityCritical controls (not repeated here).*

</details>

---

## CISA-SCuBA-Entra — 18 controls across 6 resource types

Covers: Conditional Access, Authentication Methods, Authorization, Cross-Tenant Access, Named Locations.

| Control | Title | Severity | BOD 25-01 | TCM Resource Type |
|---|---|---|---|---|
| MS.AAD.1.1v1 | Legacy authentication SHALL be blocked | SHALL | ✅ | conditionalaccesspolicy |
| MS.AAD.2.1v1 | High-risk users SHALL be blocked | SHALL | ✅ | conditionalaccesspolicy |
| MS.AAD.2.3v1 | High-risk sign-ins SHALL be blocked | SHALL | ✅ | conditionalaccesspolicy |
| MS.AAD.3.1v1 | Phishing-resistant MFA for all users | SHALL | ✅ | conditionalaccesspolicy |
| MS.AAD.3.2v1 | Alternative MFA if no phishing-resistant | SHALL | ✅ | conditionalaccesspolicy |
| MS.AAD.3.3v2 | Authenticator login context | SHALL | ✅ | authenticationmethodpolicy |
| MS.AAD.3.4v1 | Auth Methods migration to Complete | SHALL | ✅ | authenticationmethodpolicy |
| MS.AAD.3.5v2 | SMS/Voice/Email OTP disabled | SHALL | ✅ | authenticationmethodpolicy |
| MS.AAD.3.6v1 | Phishing-resistant MFA for privileged roles | SHALL | ✅ | conditionalaccesspolicy |
| MS.AAD.3.7v1 | Managed devices for authentication | SHOULD | | conditionalaccesspolicy |
| MS.AAD.3.8v1 | Managed devices for MFA registration | SHOULD | | conditionalaccesspolicy |
| MS.AAD.3.9v1 | Block device code flow | SHOULD | | conditionalaccesspolicy |
| MS.AAD.5.1v1 | Restrict app registration | SHALL | ✅ | authorizationpolicy |
| MS.AAD.5.2v1 | Restrict app consent | SHALL | ✅ | authorizationpolicy |
| MS.AAD.5.3v1 | Admin consent workflow | SHALL | ✅ | authorizationpolicy |
| MS.AAD.8.1v1 | Guest directory access limits | SHOULD | | authorizationpolicy |
| MS.AAD.8.2v1 | Guest inviter role requirement | SHOULD | | crosstenantaccesspolicy |
| MS.AAD.8.3v1 | Guest domain restrictions | SHOULD | | crosstenantaccesspolicyconfigurationpartner |

## CISA-SCuBA-Exchange — 14 controls across 12 resource types

Covers: Transport Rules, Anti-Phishing, Anti-Spam, Safe Links/Attachments, DKIM, Organization Config, Connectors.

| Control | Title | Severity | BOD 25-01 | TCM Resource Type |
|---|---|---|---|---|
| MS.EXO.1.1v2 | Disable auto-forwarding to external domains | SHALL | ✅ | hostedoutboundspamfilterpolicy |
| MS.EXO.3.1v1 | DKIM enabled for all domains | SHOULD | | dkimsigningconfig |
| MS.EXO.5.1v1 | SMTP AUTH disabled | SHALL | ✅ | organizationconfig |
| MS.EXO.6.1v1 | No contact folder sharing with all domains | SHALL | ✅ | organizationconfig |
| MS.EXO.6.2v1 | No calendar sharing with all domains | SHALL | ✅ | organizationconfig |
| MS.EXO.7.1v1 | External sender warnings | SHALL | ✅ | transportrule |
| MS.EXO.11.1v1 | Impersonation protection | SHOULD | | antiphishpolicy |
| MS.EXO.11.3v1 | Mailbox Intelligence (AI phishing) | SHOULD | | antiphishpolicy |
| MS.EXO.12.1v1 | No IP allow lists | SHOULD | | hostedcontentfilterpolicy |
| MS.EXO.12.2v1 | No safe lists | SHOULD | | hostedcontentfilterpolicy |
| MS.EXO.13.1v1 | Mailbox auditing enabled | SHALL | ✅ | organizationconfig |
| MS.EXO.14.3v1 | No allowed domains in anti-spam | SHALL | ✅ | hostedcontentfilterpolicy |
| MS.EXO.15.1v1 | Safe Links URL scanning | SHOULD | | safelinkspolicy |
| MS.EXO.15.2v1 | Safe Attachments malware scanning | SHOULD | | safeattachmentpolicy |

## CISA-SCuBA-Teams — 9 controls across 5 resource types

Covers: Federation/External Access, Meeting Policies, Messaging, App Permissions.

| Control | Title | Severity | BOD 25-01 | TCM Resource Type |
|---|---|---|---|---|
| MS.TEAMS.1.1v1 | External access per-domain only | SHALL | ✅ | federationconfiguration |
| MS.TEAMS.1.2v1 | Restrict to authorized domains | SHALL | ✅ | federationconfiguration |
| MS.TEAMS.1.3v1 | Block unmanaged user contact | SHALL | ✅ | federationconfiguration |
| MS.TEAMS.1.4v1 | Block Skype interop | SHOULD | | federationconfiguration |
| MS.TEAMS.2.1v1 | No anonymous meeting start | SHALL | ✅ | meetingpolicy |
| MS.TEAMS.2.2v1 | No anonymous auto-admit | SHOULD | | meetingconfiguration |
| MS.TEAMS.2.3v1 | No external participant control | SHOULD | | meetingpolicy |
| MS.TEAMS.4.1v1 | Approved apps only | SHOULD | | apppermissionpolicy |
| MS.TEAMS.6.1v1 | Security concern reporting | SHOULD | | messagingpolicy |

## What TCM Can (and Cannot) Monitor

TCM excels at detecting **drift from a known-good state**. When your tenant matches CISA recommendations:
- Take a snapshot → filter to CISA types → baseline → monitor → get alerted on drift

TCM **does not** check:
- DNS records (SPF, DMARC) — use ScubaGear or DNS tools
- PIM role assignments — not a TCM resource type
- Audit log configuration — manual check
- Password policies — not a TCM resource type

For full CISA SCuBA compliance assessment, pair EasyTCM with [ScubaGear](https://github.com/cisagov/ScubaGear) or [Maester](https://github.com/maester365/maester).

## Template Format

Each JSON template contains:

- **metadata** — Standard, version, category, description, source URL
- **resourceTypes** — TCM resource types to monitor (feeds `ConvertTo-TCMBaseline -Template`)
- **controls** — Individual compliance controls with:
  - `id` — Control identifier (e.g., MS.AAD.1.1v1)
  - `title` — Human-readable control name
  - `severity` — SHALL / SHOULD / MAY (per RFC 2119)
  - `bod2501` — Whether required by CISA BOD 25-01
  - `resourceTypes` — Which TCM types implement this control
  - `guidance` — How TCM drift detection maps to this control
  - `nistMapping` — NIST SP 800-53 Rev. 5 control mappings
  - `mitreMapping` — MITRE ATT&CK technique IDs

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for how to submit a template. Templates should:

1. Map to a recognized standard (CIS, CISA SCuBA, ISO 27001, etc.)
2. Include only TCM-supported resource types
3. Reference specific section numbers and control IDs
4. Be tested with `ConvertTo-TCMBaseline -TemplatePath`
