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
            'Get-TCMQuota'
            'Sync-TCMDriftToMaester'
        )

        $module = Get-Module EasyTCM
        foreach ($fn in $expectedFunctions) {
            $module.ExportedFunctions.Keys | Should -Contain $fn
        }
    }

    It 'should set module-level constants' {
        # Access via module scope
        $tcmAppId = & (Get-Module EasyTCM) { $script:TCM_APP_ID }
        $tcmAppId | Should -Be '03b07b79-c5bc-4b5e-9bfa-13acf4a99998'

        $baseUrl = & (Get-Module EasyTCM) { $script:TCM_BASE_URL }
        $baseUrl | Should -Be 'https://graph.microsoft.com/beta/admin/configurationManagement'
    }
}

Describe 'Get-TCMWorkloadResources' {
    It 'should return all 6 workloads' {
        $map = & (Get-Module EasyTCM) { Get-TCMWorkloadResources }
        $map.Keys | Should -Contain 'Entra'
        $map.Keys | Should -Contain 'Exchange'
        $map.Keys | Should -Contain 'Intune'
        $map.Keys | Should -Contain 'Teams'
        $map.Keys | Should -Contain 'Defender'
        $map.Keys | Should -Contain 'Purview'
    }

    It 'should have resource types in correct format' {
        $map = & (Get-Module EasyTCM) { Get-TCMWorkloadResources }
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
                    resourceType = 'microsoft.exchange.accepteddomain'
                    displayName  = 'contoso.com'
                    properties   = @{
                        Identity   = 'contoso.com'
                        DomainType = 'Authoritative'
                        Ensure     = 'Present'
                    }
                }
            )
        }

        $baseline = ConvertTo-TCMBaseline -SnapshotContent $mockSnapshot -DisplayName 'Test Baseline'

        $baseline | Should -Not -BeNullOrEmpty
        $baseline.displayName | Should -Be 'Test Baseline'
        $baseline.resources | Should -HaveCount 1
        $baseline.resources[0].resourceType | Should -Be 'microsoft.exchange.accepteddomain'
        $baseline.resources[0].properties.Identity | Should -Be 'contoso.com'
    }

    It 'should exclude specified resource types' {
        $mockSnapshot = @{
            resources = @(
                @{
                    resourceType = 'microsoft.exchange.accepteddomain'
                    displayName  = 'contoso.com'
                    properties   = @{ Identity = 'contoso.com'; Ensure = 'Present' }
                }
                @{
                    resourceType = 'microsoft.exchange.transportrule'
                    displayName  = 'Block External'
                    properties   = @{ Name = 'Block External'; Ensure = 'Present' }
                }
            )
        }

        $baseline = ConvertTo-TCMBaseline -SnapshotContent $mockSnapshot -ExcludeResources 'microsoft.exchange.transportrule'

        $baseline.resources | Should -HaveCount 1
        $baseline.resources[0].resourceType | Should -Be 'microsoft.exchange.accepteddomain'
    }
}

Describe 'New-TCMDriftPesterTest' {
    It 'should generate valid Pester test content' {
        $content = & (Get-Module EasyTCM) { New-TCMDriftPesterTest -OutputPath './test-drift' }

        $content | Should -Not -BeNullOrEmpty
        $content | Should -Match 'Describe'
        $content | Should -Match 'baseline\.json'
        $content | Should -Match 'current\.json'
        $content | Should -Match 'TCM-\*'
        $content | Should -Match 'Should'
    }
}
