# CISA SCuBA Baseline Templates

Pre-built templates that map **CISA Secure Cloud Business Applications (SCuBA)** controls to TCM resource types. Use these to scope your monitors to security-relevant configurations — when a CISA-relevant setting changes, TCM detects it within 6 hours.

> **EasyTCM watches the config. Maester/ScubaGear checks the rules.**
> Templates don't replace CISA compliance assessments — they ensure your TCM monitor covers the right resource types so drift on CISA-relevant settings triggers an alert.

## Available Templates

| Template | Standard | Resource Types | Controls | BOD 25-01 |
|---|---|---|---|---|
| `cisa-scuba-entra.json` | CISA SCuBA — Entra ID | 6 | 18 | 12 |
| `cisa-scuba-exchange.json` | CISA SCuBA — Exchange Online | 12 | 14 | 7 |
| `cisa-scuba-teams.json` | CISA SCuBA — Teams | 5 | 9 | 4 |

## Quick Start

```powershell
# Create a CISA-scoped monitor in one pipeline
New-TCMSnapshot -Wait `
  | ConvertTo-TCMBaseline -Template CISA-SCuBA-Entra -DisplayName 'CISA Entra' `
  | New-TCMMonitor -DisplayName 'CISA SCuBA Entra'

# Combine all three workloads
$snap = New-TCMSnapshot -Workload Entra, Exchange, Teams -Wait
ConvertTo-TCMBaseline -SnapshotContent $snap `
  -Template CISA-SCuBA-Entra, CISA-SCuBA-Exchange, CISA-SCuBA-Teams `
  -DisplayName 'CISA SCuBA Full' | New-TCMMonitor
```

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
4. Be tested with `ConvertTo-TCMBaseline -TemplatePath` and `Test-TCMCompliance`
