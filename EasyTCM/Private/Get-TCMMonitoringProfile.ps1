function Get-TCMMonitoringProfile {
    <#
    .SYNOPSIS
        Returns curated sets of resource types to monitor, ranked by security impact.
    .DESCRIPTION
        TCM's 800 resources/day quota (÷ 4 runs = 200 instances max) makes it
        critical to monitor only what matters. These profiles prioritize resources
        by security impact so users don't waste quota on low-value config.

        Profiles:
        - SecurityCritical: ~15 types — identity, access control, mail security
        - Recommended:      ~30 types — SecurityCritical + compliance & device policies
        - Full:             ~52 types — everything (likely to exceed quota)
    #>
    [CmdletBinding()]
    param()

    @{
        # The configs that, if changed, create immediate security exposure.
        # Covers identity, mail security, and federation — 80% of attack surface.
        SecurityCritical = @(
            # Entra — identity is the new perimeter
            'microsoft.entra.conditionalaccesspolicy'
            'microsoft.entra.authenticationmethodpolicy'
            'microsoft.entra.authorizationpolicy'
            'microsoft.entra.crosstenantaccesspolicy'
            'microsoft.entra.crosstenantaccesspolicyconfigurationpartner'
            'microsoft.entra.namedlocationpolicy'
            # Exchange — mail is the #1 attack vector
            'microsoft.exchange.antiphishpolicy'
            'microsoft.exchange.antiphishrule'
            'microsoft.exchange.transportrule'
            'microsoft.exchange.dkimsigningconfig'
            'microsoft.exchange.hostedcontentfilterpolicy'
            'microsoft.exchange.safeattachmentpolicy'
            'microsoft.exchange.safelinkspolicy'
            # Teams — federation = external access
            'microsoft.teams.federationconfiguration'
        )

        # SecurityCritical + role management, compliance, broader policies.
        # Good balance of coverage vs quota.
        Recommended = @(
            # All of SecurityCritical
            'microsoft.entra.conditionalaccesspolicy'
            'microsoft.entra.authenticationmethodpolicy'
            'microsoft.entra.authorizationpolicy'
            'microsoft.entra.crosstenantaccesspolicy'
            'microsoft.entra.crosstenantaccesspolicyconfigurationpartner'
            'microsoft.entra.namedlocationpolicy'
            'microsoft.exchange.antiphishpolicy'
            'microsoft.exchange.antiphishrule'
            'microsoft.exchange.transportrule'
            'microsoft.exchange.dkimsigningconfig'
            'microsoft.exchange.hostedcontentfilterpolicy'
            'microsoft.exchange.safeattachmentpolicy'
            'microsoft.exchange.safelinkspolicy'
            'microsoft.teams.federationconfiguration'
            # + Role management
            'microsoft.entra.roledefinition'
            # + Exchange org & connectors
            'microsoft.exchange.organizationconfig'
            'microsoft.exchange.inboundconnector'
            'microsoft.exchange.outboundconnector'
            'microsoft.exchange.hostedoutboundspamfilterpolicy'
            'microsoft.exchange.malwarefilterrule'
            # + Teams policies
            'microsoft.teams.meetingpolicy'
            'microsoft.teams.messagingpolicy'
            'microsoft.teams.apppermissionpolicy'
            # + Intune
            'microsoft.intune.accountprotectionlocalusergroupmembershippolicy'
        )
    }
}
