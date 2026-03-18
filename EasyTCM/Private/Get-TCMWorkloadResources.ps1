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
            'microsoft.entra.namedlocationpolicy'
            'microsoft.entra.roledefinition'
        )
        'Exchange' = @(
            'microsoft.exchange.accepteddomain'
            'microsoft.exchange.activesyncdeviceaccessrule'
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
        'SecurityAndCompliance' = @(
            'microsoft.securityandcompliance.autosensitivitylabelpolicy'
            'microsoft.securityandcompliance.caseholdpolicy'
            'microsoft.securityandcompliance.caseholdrule'
            'microsoft.securityandcompliance.compliancecase'
            'microsoft.securityandcompliance.compliancesearch'
            'microsoft.securityandcompliance.compliancesearchaction'
            'microsoft.securityandcompliance.compliancetag'
            'microsoft.securityandcompliance.deviceconditionalaccesspolicy'
            'microsoft.securityandcompliance.deviceconfigurationpolicy'
            'microsoft.securityandcompliance.dlpcompliancepolicy'
            'microsoft.securityandcompliance.fileplanpropertyauthority'
            'microsoft.securityandcompliance.fileplanpropertycategory'
            'microsoft.securityandcompliance.fileplanpropertycitation'
            'microsoft.securityandcompliance.fileplanpropertydepartment'
            'microsoft.securityandcompliance.fileplanpropertyreferenceid'
            'microsoft.securityandcompliance.fileplanpropertysubcategory'
            'microsoft.securityandcompliance.labelpolicy'
            'microsoft.securityandcompliance.protectionalert'
            'microsoft.securityandcompliance.retentioncompliancepolicy'
            'microsoft.securityandcompliance.retentioncompliancerule'
            'microsoft.securityandcompliance.retentioneventtype'
            'microsoft.securityandcompliance.securityfilter'
            'microsoft.securityandcompliance.supervisoryreviewpolicy'
            'microsoft.securityandcompliance.supervisoryreviewrule'
        )
    }
}
