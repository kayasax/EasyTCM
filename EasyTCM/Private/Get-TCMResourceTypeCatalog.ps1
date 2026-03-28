function Get-TCMResourceTypeCatalog {
    <#
    .SYNOPSIS
        Returns enriched metadata for all known TCM resource types.
    .DESCRIPTION
        Central catalog of all 62 TCM resource types with human-readable names,
        descriptions, workload grouping, profile membership, admin portal links,
        and quota notes. Used by Show-TCMMonitor, Edit-TCMMonitor, and
        Export-TCMDriftReport as the single source of truth.

        Data merged from:
        - Get-TCMWorkloadResources (workload grouping, full type list)
        - Get-TCMMonitoringProfile (SecurityCritical/Recommended membership)
        - Template controls (display names, descriptions, severity)
        - Admin portal deep links
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Returns a catalog of multiple resource types')]
    [CmdletBinding()]
    param()

    # Build profile membership lookup
    $profiles = Get-TCMMonitoringProfile
    $scTypes = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $recTypes = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($t in $profiles.SecurityCritical) { [void]$scTypes.Add($t) }
    foreach ($t in $profiles.Recommended) { [void]$recTypes.Add($t) }

    # Helper to determine profile membership
    $getProfiles = {
        param([string]$type)
        $p = @()
        if ($scTypes.Contains($type)) { $p += 'SecurityCritical' }
        if ($recTypes.Contains($type)) { $p += 'Recommended' }
        $p += 'Full'
        $p
    }

    # Catalog: keyed by full resource type name
    # DisplayName  = human-readable name (what an admin calls it)
    # Description  = why monitoring this matters (security impact focus)
    # Severity     = SHALL (SecurityCritical), SHOULD (Recommended), MAY (Full only)
    # AdminPortal  = deep link to the admin portal page for this resource type
    # QuotaNote    = warning about high instance counts (optional)
    @{
        #region Entra ID
        'microsoft.entra.conditionalaccesspolicy' = @{
            Workload    = 'Entra'
            ShortName   = 'conditionalaccesspolicy'
            DisplayName = 'Conditional Access policies'
            Description = 'Controls who can access what and how. Changes to state, grant controls, conditions, or exclusions can open a security gap.'
            Severity    = 'SHALL'
            Profiles    = & $getProfiles 'microsoft.entra.conditionalaccesspolicy'
            AdminPortal = 'https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies'
            QuotaNote   = $null
        }
        'microsoft.entra.authenticationmethodpolicy' = @{
            Workload    = 'Entra'
            ShortName   = 'authenticationmethodpolicy'
            DisplayName = 'Authentication method policies'
            Description = 'Controls which MFA methods are enabled, migration state, and per-method configuration. Changes can weaken authentication requirements.'
            Severity    = 'SHALL'
            Profiles    = & $getProfiles 'microsoft.entra.authenticationmethodpolicy'
            AdminPortal = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods'
            QuotaNote   = $null
        }
        'microsoft.entra.authorizationpolicy' = @{
            Workload    = 'Entra'
            ShortName   = 'authorizationpolicy'
            DisplayName = 'Authorization policies'
            Description = 'Governs app registration, consent framework, guest access, and admin consent workflow. Changes affect tenant-wide permissions.'
            Severity    = 'SHALL'
            Profiles    = & $getProfiles 'microsoft.entra.authorizationpolicy'
            AdminPortal = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/TenantOverview.ReactView'
            QuotaNote   = $null
        }
        'microsoft.entra.crosstenantaccesspolicy' = @{
            Workload    = 'Entra'
            ShortName   = 'crosstenantaccesspolicy'
            DisplayName = 'Cross-tenant access policies'
            Description = 'Controls B2B collaboration trust with external organizations. Changes can expose resources to unauthorized tenants.'
            Severity    = 'SHALL'
            Profiles    = & $getProfiles 'microsoft.entra.crosstenantaccesspolicy'
            AdminPortal = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CompanyRelationshipsMenuBlade/~/CrossTenantAccessSettings'
            QuotaNote   = $null
        }
        'microsoft.entra.crosstenantaccesspolicyconfigurationpartner' = @{
            Workload    = 'Entra'
            ShortName   = 'crosstenantaccesspolicyconfigurationpartner'
            DisplayName = 'Cross-tenant partner configurations'
            Description = 'Per-partner trust settings for B2B inbound/outbound collaboration. Unauthorized changes can grant external orgs excessive trust.'
            Severity    = 'SHALL'
            Profiles    = & $getProfiles 'microsoft.entra.crosstenantaccesspolicyconfigurationpartner'
            AdminPortal = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CompanyRelationshipsMenuBlade/~/CrossTenantAccessSettings'
            QuotaNote   = $null
        }
        'microsoft.entra.namedlocationpolicy' = @{
            Workload    = 'Entra'
            ShortName   = 'namedlocationpolicy'
            DisplayName = 'Named locations'
            Description = 'Defines trusted IP ranges and countries used in CA policy conditions. Adding IPs can bypass MFA requirements.'
            Severity    = 'SHALL'
            Profiles    = & $getProfiles 'microsoft.entra.namedlocationpolicy'
            AdminPortal = 'https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/NamedLocations'
            QuotaNote   = $null
        }
        'microsoft.entra.roledefinition' = @{
            Workload    = 'Entra'
            ShortName   = 'roledefinition'
            DisplayName = 'Role definitions'
            Description = 'Built-in and custom Entra role definitions. Monitoring detects permission changes to custom roles.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.entra.roledefinition'
            AdminPortal = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/RolesManagementMenuBlade/~/AllRoles'
            QuotaNote   = 'High instance count (~100+ built-in roles). Consumes significant quota.'
        }
        'microsoft.entra.administrativeunit' = @{
            Workload    = 'Entra'
            ShortName   = 'administrativeunit'
            DisplayName = 'Administrative units'
            Description = 'Scoped management units for delegated administration. Changes can alter who manages which users and groups.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.entra.administrativeunit'
            AdminPortal = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AdminUnitsBlade'
            QuotaNote   = $null
        }
        'microsoft.entra.grouplifecyclepolicy' = @{
            Workload    = 'Entra'
            ShortName   = 'grouplifecyclepolicy'
            DisplayName = 'Group lifecycle policies'
            Description = 'Controls M365 group expiration and renewal. Changes can cause unexpected group deletions or disable cleanup.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.entra.grouplifecyclepolicy'
            AdminPortal = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/Lifecycle'
            QuotaNote   = $null
        }
        'microsoft.entra.externalidentitypolicy' = @{
            Workload    = 'Entra'
            ShortName   = 'externalidentitypolicy'
            DisplayName = 'External identity policies'
            Description = 'Controls whether external users can leave the guest tenant via self-service. Changes affect guest lifecycle management.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.entra.externalidentitypolicy'
            AdminPortal = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CompanyRelationshipsMenuBlade/~/Settings'
            QuotaNote   = $null
        }
        #endregion

        #region Exchange Online
        'microsoft.exchange.antiphishpolicy' = @{
            Workload    = 'Exchange'
            ShortName   = 'antiphishpolicy'
            DisplayName = 'Anti-phishing policies'
            Description = 'Impersonation protection and phishing thresholds. Weakening these exposes users to credential harvesting.'
            Severity    = 'SHALL'
            Profiles    = & $getProfiles 'microsoft.exchange.antiphishpolicy'
            AdminPortal = 'https://security.microsoft.com/antiphishing'
            QuotaNote   = $null
        }
        'microsoft.exchange.antiphishrule' = @{
            Workload    = 'Exchange'
            ShortName   = 'antiphishrule'
            DisplayName = 'Anti-phishing rules'
            Description = 'Scoping rules that determine which users are protected by anti-phish policies. Changes can exclude users from protection.'
            Severity    = 'SHALL'
            Profiles    = & $getProfiles 'microsoft.exchange.antiphishrule'
            AdminPortal = 'https://security.microsoft.com/antiphishing'
            QuotaNote   = $null
        }
        'microsoft.exchange.transportrule' = @{
            Workload    = 'Exchange'
            ShortName   = 'transportrule'
            DisplayName = 'Transport rules (mail flow)'
            Description = 'Mail flow rules that route, modify, or block email. Unauthorized rules can redirect or exfiltrate mail silently.'
            Severity    = 'SHALL'
            Profiles    = & $getProfiles 'microsoft.exchange.transportrule'
            AdminPortal = 'https://admin.exchange.microsoft.com/#/transportrules'
            QuotaNote   = $null
        }
        'microsoft.exchange.dkimsigningconfig' = @{
            Workload    = 'Exchange'
            ShortName   = 'dkimsigningconfig'
            DisplayName = 'DKIM signing configuration'
            Description = 'DomainKeys Identified Mail signing for outbound email. Disabling DKIM can cause delivery failures and enable spoofing.'
            Severity    = 'SHALL'
            Profiles    = & $getProfiles 'microsoft.exchange.dkimsigningconfig'
            AdminPortal = 'https://security.microsoft.com/dkimv2'
            QuotaNote   = $null
        }
        'microsoft.exchange.hostedcontentfilterpolicy' = @{
            Workload    = 'Exchange'
            ShortName   = 'hostedcontentfilterpolicy'
            DisplayName = 'Anti-spam policies'
            Description = 'Spam filtering settings including allowed/blocked senders and domains. Adding allowed domains can bypass spam protection.'
            Severity    = 'SHALL'
            Profiles    = & $getProfiles 'microsoft.exchange.hostedcontentfilterpolicy'
            AdminPortal = 'https://security.microsoft.com/antispam'
            QuotaNote   = $null
        }
        'microsoft.exchange.safeattachmentpolicy' = @{
            Workload    = 'Exchange'
            ShortName   = 'safeattachmentpolicy'
            DisplayName = 'Safe Attachments policies'
            Description = 'Sandbox detonation of email attachments. Disabling allows malicious attachments through.'
            Severity    = 'SHALL'
            Profiles    = & $getProfiles 'microsoft.exchange.safeattachmentpolicy'
            AdminPortal = 'https://security.microsoft.com/safeattachmentv2'
            QuotaNote   = $null
        }
        'microsoft.exchange.safelinkspolicy' = @{
            Workload    = 'Exchange'
            ShortName   = 'safelinkspolicy'
            DisplayName = 'Safe Links policies'
            Description = 'URL rewriting and click-time scanning. Disabling removes protection against malicious links in email.'
            Severity    = 'SHALL'
            Profiles    = & $getProfiles 'microsoft.exchange.safelinkspolicy'
            AdminPortal = 'https://security.microsoft.com/safelinksv2'
            QuotaNote   = $null
        }
        'microsoft.exchange.organizationconfig' = @{
            Workload    = 'Exchange'
            ShortName   = 'organizationconfig'
            DisplayName = 'Exchange organization configuration'
            Description = 'Tenant-wide Exchange settings: mailbox auditing, SMTP AUTH, sharing policies. Changes affect all mailboxes.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.exchange.organizationconfig'
            AdminPortal = 'https://admin.exchange.microsoft.com/#/settings'
            QuotaNote   = $null
        }
        'microsoft.exchange.inboundconnector' = @{
            Workload    = 'Exchange'
            ShortName   = 'inboundconnector'
            DisplayName = 'Inbound mail connectors'
            Description = 'Route inbound mail from partner orgs or on-premises. Unauthorized connectors can inject mail bypassing security.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.exchange.inboundconnector'
            AdminPortal = 'https://admin.exchange.microsoft.com/#/connectors'
            QuotaNote   = $null
        }
        'microsoft.exchange.outboundconnector' = @{
            Workload    = 'Exchange'
            ShortName   = 'outboundconnector'
            DisplayName = 'Outbound mail connectors'
            Description = 'Route outbound mail to partner orgs or on-premises. Unauthorized connectors can exfiltrate mail.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.exchange.outboundconnector'
            AdminPortal = 'https://admin.exchange.microsoft.com/#/connectors'
            QuotaNote   = $null
        }
        'microsoft.exchange.hostedoutboundspamfilterpolicy' = @{
            Workload    = 'Exchange'
            ShortName   = 'hostedoutboundspamfilterpolicy'
            DisplayName = 'Outbound spam filter policy'
            Description = 'Controls auto-forwarding rules and outbound spam thresholds. Disabling forwarding restrictions can enable data exfiltration.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.exchange.hostedoutboundspamfilterpolicy'
            AdminPortal = 'https://security.microsoft.com/antispam'
            QuotaNote   = $null
        }
        'microsoft.exchange.malwarefilterrule' = @{
            Workload    = 'Exchange'
            ShortName   = 'malwarefilterrule'
            DisplayName = 'Malware filter rules'
            Description = 'Malware detection scope and actions. Changes to rule conditions can exclude users from malware protection.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.exchange.malwarefilterrule'
            AdminPortal = 'https://security.microsoft.com/antimalwarev2'
            QuotaNote   = $null
        }
        'microsoft.exchange.accepteddomain' = @{
            Workload    = 'Exchange'
            ShortName   = 'accepteddomain'
            DisplayName = 'Accepted domains'
            Description = 'Domains accepted for inbound mail delivery. Adding domains can enable mail interception.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.exchange.accepteddomain'
            AdminPortal = 'https://admin.exchange.microsoft.com/#/accepteddomains'
            QuotaNote   = $null
        }
        'microsoft.exchange.activesyncdeviceaccessrule' = @{
            Workload    = 'Exchange'
            ShortName   = 'activesyncdeviceaccessrule'
            DisplayName = 'ActiveSync device access rules'
            Description = 'Controls which mobile devices can connect via ActiveSync. Changes can allow unmanaged devices to access email.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.exchange.activesyncdeviceaccessrule'
            AdminPortal = 'https://admin.exchange.microsoft.com/#/mobiledeviceaccess'
            QuotaNote   = $null
        }
        'microsoft.exchange.distributiongroup' = @{
            Workload    = 'Exchange'
            ShortName   = 'distributiongroup'
            DisplayName = 'Distribution groups'
            Description = 'Mail distribution groups and their membership. Changes can alter who receives sensitive communications.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.exchange.distributiongroup'
            AdminPortal = 'https://admin.exchange.microsoft.com/#/groups'
            QuotaNote   = 'Can be high instance count in large tenants.'
        }
        'microsoft.exchange.mailcontact' = @{
            Workload    = 'Exchange'
            ShortName   = 'mailcontact'
            DisplayName = 'Mail contacts'
            Description = 'External mail contacts in the address book. Changes can redirect mail intended for external partners.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.exchange.mailcontact'
            AdminPortal = 'https://admin.exchange.microsoft.com/#/contacts'
            QuotaNote   = $null
        }
        'microsoft.exchange.remotedomain' = @{
            Workload    = 'Exchange'
            ShortName   = 'remotedomain'
            DisplayName = 'Remote domains'
            Description = 'Controls message format and policies for mail sent to external domains. Changes can enable auto-forwarding to specific domains.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.exchange.remotedomain'
            AdminPortal = 'https://admin.exchange.microsoft.com/#/remotedomains'
            QuotaNote   = $null
        }
        'microsoft.exchange.sharedmailbox' = @{
            Workload    = 'Exchange'
            ShortName   = 'sharedmailbox'
            DisplayName = 'Shared mailboxes'
            Description = 'Shared mailboxes and their delegate access. Changes can grant unauthorized users access to shared resources.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.exchange.sharedmailbox'
            AdminPortal = 'https://admin.exchange.microsoft.com/#/sharedmailboxes'
            QuotaNote   = 'Can be high instance count in large tenants.'
        }
        #endregion

        #region Teams
        'microsoft.teams.federationconfiguration' = @{
            Workload    = 'Teams'
            ShortName   = 'federationconfiguration'
            DisplayName = 'Teams federation configuration'
            Description = 'Controls which external domains can communicate with your users. Changes can expose internal chat to unauthorized orgs.'
            Severity    = 'SHALL'
            Profiles    = & $getProfiles 'microsoft.teams.federationconfiguration'
            AdminPortal = 'https://admin.teams.microsoft.com/company-wide-settings/external-communications'
            QuotaNote   = $null
        }
        'microsoft.teams.meetingpolicy' = @{
            Workload    = 'Teams'
            ShortName   = 'meetingpolicy'
            DisplayName = 'Meeting policies'
            Description = 'Controls who can join meetings, present, record, and use AI features. Changes can expose meeting content to external participants.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.teams.meetingpolicy'
            AdminPortal = 'https://admin.teams.microsoft.com/policies/meetings'
            QuotaNote   = $null
        }
        'microsoft.teams.messagingpolicy' = @{
            Workload    = 'Teams'
            ShortName   = 'messagingpolicy'
            DisplayName = 'Messaging policies'
            Description = 'Controls message editing, deletion, read receipts, and URL previews in Teams chat.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.teams.messagingpolicy'
            AdminPortal = 'https://admin.teams.microsoft.com/policies/messaging'
            QuotaNote   = $null
        }
        'microsoft.teams.apppermissionpolicy' = @{
            Workload    = 'Teams'
            ShortName   = 'apppermissionpolicy'
            DisplayName = 'App permission policies'
            Description = 'Controls which apps users can install in Teams. Loosening restrictions can allow data-exfiltrating or malicious apps.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.teams.apppermissionpolicy'
            AdminPortal = 'https://admin.teams.microsoft.com/policies/app-permission'
            QuotaNote   = $null
        }
        'microsoft.teams.meetingconfiguration' = @{
            Workload    = 'Teams'
            ShortName   = 'meetingconfiguration'
            DisplayName = 'Meeting configuration'
            Description = 'Tenant-wide meeting settings including lobby, anonymous join, and PSTN. Changes affect all meetings.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.teams.meetingconfiguration'
            AdminPortal = 'https://admin.teams.microsoft.com/meetings/settings'
            QuotaNote   = $null
        }
        'microsoft.teams.callingpolicy' = @{
            Workload    = 'Teams'
            ShortName   = 'callingpolicy'
            DisplayName = 'Calling policies'
            Description = 'Controls call forwarding, delegation, voicemail, and busy-on-busy for Teams phone. Changes can enable call forwarding to external numbers.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.teams.callingpolicy'
            AdminPortal = 'https://admin.teams.microsoft.com/policies/calling'
            QuotaNote   = $null
        }
        'microsoft.teams.channelspolicy' = @{
            Workload    = 'Teams'
            ShortName   = 'channelspolicy'
            DisplayName = 'Channels policies'
            Description = 'Controls shared channel creation and external participant access. Changes can expose team content to external users.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.teams.channelspolicy'
            AdminPortal = 'https://admin.teams.microsoft.com/policies/channels'
            QuotaNote   = $null
        }
        'microsoft.teams.dialinconferencingtenantsettings' = @{
            Workload    = 'Teams'
            ShortName   = 'dialinconferencingtenantsettings'
            DisplayName = 'Audio conferencing settings'
            Description = 'Dial-in conferencing bridges and default phone numbers. Changes affect meeting join experience.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.teams.dialinconferencingtenantsettings'
            AdminPortal = 'https://admin.teams.microsoft.com/meetings/conference-bridges'
            QuotaNote   = $null
        }
        'microsoft.teams.meetingbroadcastpolicy' = @{
            Workload    = 'Teams'
            ShortName   = 'meetingbroadcastpolicy'
            DisplayName = 'Live events policies'
            Description = 'Controls who can schedule and join Teams live events (broadcasts). Changes can allow public broadcasts.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.teams.meetingbroadcastpolicy'
            AdminPortal = 'https://admin.teams.microsoft.com/policies/broadcasts'
            QuotaNote   = $null
        }
        #endregion

        #region Intune
        'microsoft.intune.accountprotectionlocalusergroupmembershippolicy' = @{
            Workload    = 'Intune'
            ShortName   = 'accountprotectionlocalusergroupmembershippolicy'
            DisplayName = 'Account protection (local group membership)'
            Description = 'Controls local admin group membership on managed devices. Changes can grant local admin to unauthorized users.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.intune.accountprotectionlocalusergroupmembershippolicy'
            AdminPortal = 'https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configuration'
            QuotaNote   = $null
        }
        #endregion

        #region SecurityAndCompliance
        'microsoft.securityandcompliance.dlpcompliancepolicy' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'dlpcompliancepolicy'
            DisplayName = 'DLP compliance policies'
            Description = 'Data Loss Prevention policies protecting sensitive data in Exchange, SharePoint, OneDrive, and Teams. Weakening DLP can expose PII, financial, or health data.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.dlpcompliancepolicy'
            AdminPortal = 'https://compliance.microsoft.com/datalossprevention'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.retentioncompliancepolicy' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'retentioncompliancepolicy'
            DisplayName = 'Retention compliance policies'
            Description = 'Policies ensuring data is kept for compliance or deleted on schedule. Changes can violate regulatory requirements.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.retentioncompliancepolicy'
            AdminPortal = 'https://compliance.microsoft.com/informationgovernance'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.retentioncompliancerule' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'retentioncompliancerule'
            DisplayName = 'Retention compliance rules'
            Description = 'Rules within retention policies defining retention duration and actions. Changes can alter data lifecycle.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.retentioncompliancerule'
            AdminPortal = 'https://compliance.microsoft.com/informationgovernance'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.labelpolicy' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'labelpolicy'
            DisplayName = 'Sensitivity label policies'
            Description = 'Policies publishing sensitivity and retention labels to users. Changes can remove classification options.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.labelpolicy'
            AdminPortal = 'https://compliance.microsoft.com/informationprotection'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.compliancetag' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'compliancetag'
            DisplayName = 'Compliance tags (retention labels)'
            Description = 'Retention labels applied to content for lifecycle management. Changes can alter how long data is kept.'
            Severity    = 'SHOULD'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.compliancetag'
            AdminPortal = 'https://compliance.microsoft.com/informationgovernance?viewid=labels'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.autosensitivitylabelpolicy' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'autosensitivitylabelpolicy'
            DisplayName = 'Auto-labeling policies'
            Description = 'Automatic sensitivity label assignment based on content inspection. Changes can stop auto-classification of sensitive data.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.autosensitivitylabelpolicy'
            AdminPortal = 'https://compliance.microsoft.com/informationprotection?viewid=autolabeling'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.caseholdpolicy' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'caseholdpolicy'
            DisplayName = 'eDiscovery case hold policies'
            Description = 'Legal hold policies for eDiscovery cases. Removing holds can allow evidence destruction.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.caseholdpolicy'
            AdminPortal = 'https://compliance.microsoft.com/advancedediscovery'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.caseholdrule' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'caseholdrule'
            DisplayName = 'eDiscovery case hold rules'
            Description = 'Rules within case hold policies defining what content is preserved. Changes can narrow or remove preservations.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.caseholdrule'
            AdminPortal = 'https://compliance.microsoft.com/advancedediscovery'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.compliancecase' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'compliancecase'
            DisplayName = 'eDiscovery compliance cases'
            Description = 'eDiscovery case containers for investigations. Changes can close cases or alter scope.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.compliancecase'
            AdminPortal = 'https://compliance.microsoft.com/advancedediscovery'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.compliancesearch' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'compliancesearch'
            DisplayName = 'Compliance searches'
            Description = 'Content search definitions across Exchange, SharePoint, and OneDrive. Changes can alter search scope.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.compliancesearch'
            AdminPortal = 'https://compliance.microsoft.com/contentsearchv2'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.compliancesearchaction' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'compliancesearchaction'
            DisplayName = 'Compliance search actions'
            Description = 'Actions on search results (preview, export, purge). Changes can trigger data deletion or export.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.compliancesearchaction'
            AdminPortal = 'https://compliance.microsoft.com/contentsearchv2'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.deviceconditionalaccesspolicy' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'deviceconditionalaccesspolicy'
            DisplayName = 'Device conditional access policies (Purview)'
            Description = 'Purview-managed device access policies. Changes can loosen device compliance requirements.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.deviceconditionalaccesspolicy'
            AdminPortal = 'https://compliance.microsoft.com/compliancesettings'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.deviceconfigurationpolicy' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'deviceconfigurationpolicy'
            DisplayName = 'Device configuration policies (Purview)'
            Description = 'Purview-managed device configuration baselines. Changes can weaken device security settings.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.deviceconfigurationpolicy'
            AdminPortal = 'https://compliance.microsoft.com/compliancesettings'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.fileplanpropertyauthority' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'fileplanpropertyauthority'
            DisplayName = 'File plan authorities'
            Description = 'Regulatory authority references for records management file plans.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.fileplanpropertyauthority'
            AdminPortal = 'https://compliance.microsoft.com/recordsmanagement'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.fileplanpropertycategory' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'fileplanpropertycategory'
            DisplayName = 'File plan categories'
            Description = 'Business function categories for records management file plans.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.fileplanpropertycategory'
            AdminPortal = 'https://compliance.microsoft.com/recordsmanagement'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.fileplanpropertycitation' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'fileplanpropertycitation'
            DisplayName = 'File plan citations'
            Description = 'Regulatory citation references for records management file plans.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.fileplanpropertycitation'
            AdminPortal = 'https://compliance.microsoft.com/recordsmanagement'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.fileplanpropertydepartment' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'fileplanpropertydepartment'
            DisplayName = 'File plan departments'
            Description = 'Department references for records management file plans.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.fileplanpropertydepartment'
            AdminPortal = 'https://compliance.microsoft.com/recordsmanagement'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.fileplanpropertyreferenceid' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'fileplanpropertyreferenceid'
            DisplayName = 'File plan reference IDs'
            Description = 'Reference ID values for records management file plans.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.fileplanpropertyreferenceid'
            AdminPortal = 'https://compliance.microsoft.com/recordsmanagement'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.fileplanpropertysubcategory' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'fileplanpropertysubcategory'
            DisplayName = 'File plan subcategories'
            Description = 'Subcategory values for records management file plans.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.fileplanpropertysubcategory'
            AdminPortal = 'https://compliance.microsoft.com/recordsmanagement'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.protectionalert' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'protectionalert'
            DisplayName = 'Protection alerts'
            Description = 'Alert policies in Security & Compliance. Disabling alerts can hide security incidents.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.protectionalert'
            AdminPortal = 'https://compliance.microsoft.com/compliancealerts'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.retentioneventtype' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'retentioneventtype'
            DisplayName = 'Retention event types'
            Description = 'Event-based retention trigger definitions. Changes can alter when retention actions are triggered.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.retentioneventtype'
            AdminPortal = 'https://compliance.microsoft.com/recordsmanagement?viewid=events'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.securityfilter' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'securityfilter'
            DisplayName = 'Compliance security filters'
            Description = 'Search permission filters that restrict content search scope by user or site. Changes can expose protected content.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.securityfilter'
            AdminPortal = 'https://compliance.microsoft.com/contentsearchv2'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.supervisoryreviewpolicy' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'supervisoryreviewpolicy'
            DisplayName = 'Supervisory review policies'
            Description = 'Communication compliance policies for monitoring employee communications. Changes can disable mandatory oversight.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.supervisoryreviewpolicy'
            AdminPortal = 'https://compliance.microsoft.com/supervisoryreview'
            QuotaNote   = $null
        }
        'microsoft.securityandcompliance.supervisoryreviewrule' = @{
            Workload    = 'SecurityAndCompliance'
            ShortName   = 'supervisoryreviewrule'
            DisplayName = 'Supervisory review rules'
            Description = 'Rules within supervisory review policies defining what communications are monitored.'
            Severity    = 'MAY'
            Profiles    = & $getProfiles 'microsoft.securityandcompliance.supervisoryreviewrule'
            AdminPortal = 'https://compliance.microsoft.com/supervisoryreview'
            QuotaNote   = $null
        }
        #endregion
    }
}
