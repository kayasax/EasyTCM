function Get-TCMWorkloadResources {
    <#
    .SYNOPSIS
        Returns the known TCM resource type names grouped by workload.
    .DESCRIPTION
        Internal reference mapping of workload names to their TCM resource type prefixes.
        Used by snapshot and monitor cmdlets to resolve workload shortcuts.
    #>
    [CmdletBinding()]
    param()

    @{
        'Entra' = @(
            'microsoft.entra.administrativeunit'
            'microsoft.entra.authenticationmethodpolicy'
            'microsoft.entra.authorizationpolicy'
            'microsoft.entra.conditionalaccesspolicy'
            'microsoft.entra.crosstenantaccesspolicy'
            'microsoft.entra.crosstenantaccesspolicyconfigurationpartner'
            'microsoft.entra.externalidentitypolicy'
            'microsoft.entra.grouplifecyclepolicy'
            'microsoft.entra.identitygovernancelifecycleworkflow'
            'microsoft.entra.namedlocationpolicy'
            'microsoft.entra.roledefinition'
            'microsoft.entra.rolemanagementpolicy'
            'microsoft.entra.securitydefaultspolicy'
        )
        'Exchange' = @(
            'microsoft.exchange.accepteddomain'
            'microsoft.exchange.activesyncdeviceaccessrule'
            'microsoft.exchange.addressbookpolicy'
            'microsoft.exchange.antiphishpolicy'
            'microsoft.exchange.antiphishrule'
            'microsoft.exchange.distributiongroup'
            'microsoft.exchange.dkimsigningconfig'
            'microsoft.exchange.hostedcontentfilterpolicy'
            'microsoft.exchange.hostedoutboundspamfilterpolicy'
            'microsoft.exchange.inboundconnector'
            'microsoft.exchange.mailcontact'
            'microsoft.exchange.malwarefilterrule'
            'microsoft.exchange.organizationconfig'
            'microsoft.exchange.outboundconnector'
            'microsoft.exchange.remotedomain'
            'microsoft.exchange.safeattachmentpolicy'
            'microsoft.exchange.safelinkspolicy'
            'microsoft.exchange.sharedmailbox'
            'microsoft.exchange.transportrule'
        )
        'Intune' = @(
            'microsoft.intune.accountprotectionlocalusergroupmembershippolicy'
            'microsoft.intune.devicecompliancepolicy'
            'microsoft.intune.deviceconfigurationpolicy'
        )
        'Teams' = @(
            'microsoft.teams.apppermissionpolicy'
            'microsoft.teams.callingpolicy'
            'microsoft.teams.channelspolicy'
            'microsoft.teams.dialinconferencingtenantsettings'
            'microsoft.teams.federationconfiguration'
            'microsoft.teams.meetingbroadcastpolicy'
            'microsoft.teams.meetingconfiguration'
            'microsoft.teams.meetingpolicy'
            'microsoft.teams.messagingpolicy'
        )
        'Defender' = @(
            'microsoft.defender.safeattachmentpolicy'
            'microsoft.defender.safelinkspolicy'
        )
        'Purview' = @(
            'microsoft.purview.autosensitivitylabelpolicy'
            'microsoft.purview.deviceconfigurationpolicy'
            'microsoft.purview.labelpolicy'
            'microsoft.purview.retentioncompliancepolicy'
            'microsoft.purview.retentioncompliancerule'
            'microsoft.purview.sensitivitylabel'
        )
    }
}
