BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'EasyTCM' 'EasyTCM.psd1'
    # Only import if not mocked
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction SilentlyContinue
    }
}

Describe 'EasyTCM Module' {
    It 'should import without errors' {
        $modulePath = Join-Path $PSScriptRoot '..' 'EasyTCM' 'EasyTCM.psd1'
        { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
    }

    It 'should export expected functions' {
        $expectedFunctions = @(
            'Initialize-TCM'
            'Test-TCMConnection'
            'New-TCMSnapshot'
            'Get-TCMSnapshot'
            'Remove-TCMSnapshot'
            'ConvertTo-TCMBaseline'
            'New-TCMMonitor'
            'Get-TCMMonitor'
            'Update-TCMMonitor'
            'Remove-TCMMonitor'
            'Get-TCMDrift'
            'Get-TCMMonitoringResult'
            'Export-TCMDriftReport'
            'Compare-TCMBaseline'
            'Get-TCMQuota'
            'Sync-TCMDriftToMaester'
        )

        $module = Get-Module EasyTCM
        foreach ($fn in $expectedFunctions) {
            $module.ExportedFunctions.Keys | Should -Contain $fn
        }
    }

    It 'should set module-level constants' {
        # Access via module scope (Select -First 1 in case module loaded twice)
        $mod = Get-Module EasyTCM | Select-Object -First 1
        $tcmAppId = & $mod { $script:TCM_APP_ID }
        $tcmAppId | Should -Be '03b07b79-c5bc-4b5e-9bfa-13acf4a99998'

        $baseUrl = & $mod { $script:TCM_BASE_URL }
        $baseUrl | Should -Be 'https://graph.microsoft.com/beta/admin/configurationManagement'
    }
}

Describe 'Get-TCMWorkloadResources' {
    It 'should return all 5 workloads' {
        $map = & (Get-Module EasyTCM | Select-Object -First 1) { Get-TCMWorkloadResources }
        $map.Keys | Should -Contain 'Entra'
        $map.Keys | Should -Contain 'Exchange'
        $map.Keys | Should -Contain 'Intune'
        $map.Keys | Should -Contain 'Teams'
        $map.Keys | Should -Contain 'SecurityAndCompliance'
        $map.Keys.Count | Should -Be 5
    }

    It 'should have resource types in correct format' {
        $map = & (Get-Module EasyTCM | Select-Object -First 1) { Get-TCMWorkloadResources }
        foreach ($workload in $map.Keys) {
            foreach ($resource in $map[$workload]) {
                $resource | Should -Match '^microsoft\.\w+\.\w+'
            }
        }
    }
}

Describe 'ConvertTo-TCMBaseline' {
    It 'should convert snapshot content to baseline format' {
        $mockSnapshot = @{
            resources = @(
                @{
                    resourceType = 'microsoft.entra.conditionalaccesspolicy'
                    displayName  = 'Block Legacy Auth'
                    properties   = @{
                        State     = 'enabled'
                        GrantType = 'block'
                    }
                }
            )
        }

        $baseline = ConvertTo-TCMBaseline -SnapshotContent $mockSnapshot -DisplayName 'Test Baseline' -Profile Full

        $baseline | Should -Not -BeNullOrEmpty
        $baseline.displayName | Should -Be 'Test Baseline'
        $baseline.resources | Should -HaveCount 1
        $baseline.resources[0].resourceType | Should -Be 'microsoft.entra.conditionalaccesspolicy'
    }

    It 'should exclude specified resource types' {
        $mockSnapshot = @{
            resources = @(
                @{
                    resourceType = 'microsoft.entra.conditionalaccesspolicy'
                    displayName  = 'Block Legacy Auth'
                    properties   = @{ State = 'enabled' }
                }
                @{
                    resourceType = 'microsoft.exchange.transportrule'
                    displayName  = 'Block External'
                    properties   = @{ Name = 'Block External'; Ensure = 'Present' }
                }
            )
        }

        $baseline = ConvertTo-TCMBaseline -SnapshotContent $mockSnapshot -Profile Full -ExcludeResources 'microsoft.exchange.transportrule'

        $baseline.resources | Should -HaveCount 1
        $baseline.resources[0].resourceType | Should -Be 'microsoft.entra.conditionalaccesspolicy'
    }

    It 'should filter by SecurityCritical profile by default' {
        $mockSnapshot = @{
            resources = @(
                @{
                    resourceType = 'microsoft.entra.conditionalaccesspolicy'
                    displayName  = 'Block Legacy Auth'
                    properties   = @{ State = 'enabled' }
                }
                @{
                    resourceType = 'microsoft.entra.administrativeunit'
                    displayName  = 'Marketing AU'
                    properties   = @{ displayName = 'Marketing AU' }
                }
            )
        }

        # Default profile is SecurityCritical — administrative units NOT included
        $baseline = ConvertTo-TCMBaseline -SnapshotContent $mockSnapshot

        $baseline.resources | Should -HaveCount 1
        $baseline.resources[0].resourceType | Should -Be 'microsoft.entra.conditionalaccesspolicy'
    }
}

Describe 'Get-TCMMonitoringProfile' {
    It 'should return SecurityCritical and Recommended profiles' {
        $profiles = & (Get-Module EasyTCM | Select-Object -First 1) { Get-TCMMonitoringProfile }
        $profiles.Keys | Should -Contain 'SecurityCritical'
        $profiles.Keys | Should -Contain 'Recommended'
    }

    It 'should have SecurityCritical as a subset of Recommended' {
        $profiles = & (Get-Module EasyTCM | Select-Object -First 1) { Get-TCMMonitoringProfile }
        foreach ($type in $profiles.SecurityCritical) {
            $profiles.Recommended | Should -Contain $type
        }
    }
}

Describe 'New-TCMSnapshot defaults' {
    It 'should default to all workloads when none specified' {
        # Verify the function doesn't throw when called without -Workloads/-Resources
        # by checking the parameter defaults
        $cmd = Get-Command New-TCMSnapshot -Module EasyTCM
        $resourcesParam = $cmd.Parameters['Resources']
        $workloadsParam = $cmd.Parameters['Workloads']
        # Neither should be mandatory
        $resourcesParam.Attributes.Mandatory | Should -Not -Contain $true
        $workloadsParam.Attributes.Mandatory | Should -Not -Contain $true
    }
}

Describe 'Compare-TCMBaseline' {
    It 'should have expected parameters' {
        $cmd = Get-Command Compare-TCMBaseline -Module EasyTCM
        $cmd.Parameters.Keys | Should -Contain 'MonitorId'
        $cmd.Parameters.Keys | Should -Contain 'Detailed'
        $cmd.Parameters.Keys | Should -Contain 'KeepSnapshot'
    }

    It 'should support ShouldProcess (WhatIf)' {
        $cmd = Get-Command Compare-TCMBaseline -Module EasyTCM
        $cmd.Parameters.Keys | Should -Contain 'WhatIf'
    }
}
