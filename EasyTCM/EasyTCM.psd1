#
# Module manifest for module 'EasyTCM'
#

@{
    # Script module file associated with this manifest
    RootModule        = 'EasyTCM.psm1'

    # Version number of this module
    ModuleVersion     = '0.1.0'

    # ID used to uniquely identify this module
    GUID              = 'a3f7c8d2-5e1b-4a9f-b0c6-d8e2f1a4b5c7'

    # Author of this module
    Author            = 'Loic MICHEL'

    # Company or vendor of this module
    #CompanyName       = 'Community'

    # Copyright statement for this module
    Copyright         = '(c) 2026 Loic MICHEL. All rights reserved. MIT License.'

    # Description of the functionality provided by this module
    Description       = 'Simplify Microsoft 365 Tenant Configuration Management (TCM) APIs. The EasyPIM approach for tenant-wide configuration monitoring, drift detection, and Maester integration.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0' }
    )

    # Functions to export from this module
    FunctionsToExport = @(
        # Setup
        'Initialize-TCM'
        'Test-TCMConnection'
        # Snapshots
        'New-TCMSnapshot'
        'Get-TCMSnapshot'
        'Remove-TCMSnapshot'
        'ConvertTo-TCMBaseline'
        # Monitors
        'New-TCMMonitor'
        'Get-TCMMonitor'
        'Update-TCMMonitor'
        'Remove-TCMMonitor'
        # Drift
        'Get-TCMDrift'
        'Get-TCMMonitoringResult'
        'Export-TCMDriftReport'
        # Quota
        'Get-TCMQuota'
        # Maester Bridge
        'Sync-TCMDriftToMaester'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport  = @()

    # Aliases to export from this module
    AliasesToExport    = @()

    # Private data to pass to the module specified in RootModule
    PrivateData       = @{
        PSData = @{
            Tags         = @('TCM', 'TenantConfiguration', 'Microsoft365', 'Maester', 'Drift', 'ConfigurationManagement', 'MicrosoftGraph')
            LicenseUri   = 'https://github.com/kayasax/EasyTCM/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/kayasax/EasyTCM'
            ReleaseNotes = 'Initial preview release — TCM setup, snapshots, monitors, drift detection, and Maester bridge.'
        }
    }
}
