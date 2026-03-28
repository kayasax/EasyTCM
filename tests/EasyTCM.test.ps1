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
            'Add-TCMMonitorType'
            'Get-TCMDrift'
            'Get-TCMMonitoringResult'
            'Export-TCMDriftReport'
            'Compare-TCMBaseline'
            'Get-TCMQuota'
            'Sync-TCMDriftToMaester'
            'Start-TCMMonitoring'
            'Show-TCMDrift'
            'Update-TCMBaseline'
            'Register-TCMSchedule'
            'Show-TCMMonitor'
            'Edit-TCMMonitor'
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

Describe 'Get-TCMResourceTypeCatalog' {
    BeforeAll {
        $catalog = & (Get-Module EasyTCM | Select-Object -First 1) { Get-TCMResourceTypeCatalog }
    }

    It 'should return all 62 resource types' {
        $catalog.Count | Should -Be 62
    }

    It 'should have all required keys on every entry' {
        $requiredKeys = @('Workload', 'ShortName', 'DisplayName', 'Description', 'Severity', 'Profiles', 'AdminPortal')
        foreach ($key in $catalog.Keys) {
            $entry = $catalog[$key]
            foreach ($rk in $requiredKeys) {
                $entry.ContainsKey($rk) | Should -BeTrue -Because "$key should have key '$rk'"
            }
        }
    }

    It 'should cover all workloads in Get-TCMWorkloadResources' {
        $workloads = & (Get-Module EasyTCM | Select-Object -First 1) { Get-TCMWorkloadResources }
        foreach ($wl in $workloads.Keys) {
            foreach ($type in $workloads[$wl]) {
                $fullKey = if ($type -like 'microsoft.*') { $type } else { "microsoft.$($wl.ToLower()).$type" }
                $catalog.ContainsKey($fullKey) | Should -BeTrue -Because "$fullKey should be in catalog"
            }
        }
    }

    It 'should have profiles matching Get-TCMMonitoringProfile' {
        $profiles = & (Get-Module EasyTCM | Select-Object -First 1) { Get-TCMMonitoringProfile }
        foreach ($type in $profiles.SecurityCritical) {
            $catalog[$type].Profiles | Should -Contain 'SecurityCritical' -Because "$type is SecurityCritical"
        }
        foreach ($type in $profiles.Recommended) {
            $catalog[$type].Profiles | Should -Contain 'Recommended' -Because "$type is Recommended"
        }
    }

    It 'should have valid severity values' {
        foreach ($key in $catalog.Keys) {
            $catalog[$key].Severity | Should -BeIn @('SHALL', 'SHOULD', 'MAY') -Because "$key severity"
        }
    }
}

Describe 'Show-TCMMonitor' {
    It 'should accept -ProfileName parameter' {
        $cmd = Get-Command Show-TCMMonitor -Module EasyTCM
        $cmd.Parameters.ContainsKey('ProfileName') | Should -BeTrue
    }

    It 'should accept -Browser parameter' {
        $cmd = Get-Command Show-TCMMonitor -Module EasyTCM
        $cmd.Parameters.ContainsKey('Browser') | Should -BeTrue
    }

    It 'should validate ProfileName values' {
        $cmd = Get-Command Show-TCMMonitor -Module EasyTCM
        $validateSet = $cmd.Parameters['ProfileName'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $validateSet.ValidValues | Should -Contain 'SecurityCritical'
        $validateSet.ValidValues | Should -Contain 'Recommended'
        $validateSet.ValidValues | Should -Contain 'Full'
    }

    It 'should display profile preview without errors' {
        { Show-TCMMonitor -ProfileName SecurityCritical } | Should -Not -Throw
    }
}

Describe 'Edit-TCMMonitor' {
    It 'should exist as an exported function' {
        $cmd = Get-Command Edit-TCMMonitor -Module EasyTCM -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
    }

    It 'should accept -ResourceTypes parameter' {
        $cmd = Get-Command Edit-TCMMonitor -Module EasyTCM
        $cmd.Parameters.ContainsKey('ResourceTypes') | Should -BeTrue
    }

    It 'should support ShouldProcess (WhatIf)' {
        $cmd = Get-Command Edit-TCMMonitor -Module EasyTCM
        $cmd.Parameters.ContainsKey('WhatIf') | Should -BeTrue
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

Describe 'ConvertTo-TCMBaseline -Template' {
    BeforeAll {
        $templatesDir = Join-Path $PSScriptRoot '..' 'templates'
    }

    It 'should have CISA SCuBA Entra template file' {
        Join-Path $templatesDir 'cisa-scuba-entra.json' | Should -Exist
    }

    It 'should have CISA SCuBA Exchange template file' {
        Join-Path $templatesDir 'cisa-scuba-exchange.json' | Should -Exist
    }

    It 'should have CISA SCuBA Teams template file' {
        Join-Path $templatesDir 'cisa-scuba-teams.json' | Should -Exist
    }

    It 'should accept -Template parameter' {
        $cmd = Get-Command ConvertTo-TCMBaseline -Module EasyTCM
        $cmd.Parameters.Keys | Should -Contain 'Template'
        $cmd.Parameters.Keys | Should -Contain 'TemplatePath'
    }

    It 'should filter resources by template resource types' {
        $mockSnapshot = @{
            resources = @(
                @{
                    resourceType = 'microsoft.entra.conditionalaccesspolicy'
                    displayName  = 'Block Legacy Auth'
                    properties   = @{ State = 'enabled'; GrantType = 'block' }
                }
                @{
                    resourceType = 'microsoft.intune.devicecompliancepolicy'
                    displayName  = 'Windows Compliance'
                    properties   = @{ State = 'active' }
                }
            )
        }

        $templateFile = Join-Path $templatesDir 'cisa-scuba-entra.json'
        $baseline = ConvertTo-TCMBaseline -SnapshotContent $mockSnapshot -TemplatePath $templateFile -DisplayName 'Template Test'

        # Only the CA policy should survive — Intune not in Entra template
        $baseline.Resources | Should -HaveCount 1
        $baseline.Resources[0].ResourceType | Should -Be 'microsoft.entra.conditionalaccesspolicy'
    }

    It 'should merge resource types from multiple templates' {
        $mockSnapshot = @{
            resources = @(
                @{
                    resourceType = 'microsoft.entra.conditionalaccesspolicy'
                    displayName  = 'Block Legacy Auth'
                    properties   = @{ State = 'enabled' }
                }
                @{
                    resourceType = 'microsoft.exchange.transportrule'
                    displayName  = 'External Warning'
                    properties   = @{ Name = 'External Warning' }
                }
            )
        }

        $entraFile = Join-Path $templatesDir 'cisa-scuba-entra.json'
        $exoFile = Join-Path $templatesDir 'cisa-scuba-exchange.json'
        $baseline = ConvertTo-TCMBaseline -SnapshotContent $mockSnapshot -TemplatePath $entraFile, $exoFile

        # Both should survive — one from Entra template, one from Exchange template
        $baseline.Resources | Should -HaveCount 2
    }
}

Describe 'CISA SCuBA Template Structure' {
    BeforeAll {
        $templatesDir = Join-Path $PSScriptRoot '..' 'templates'
    }

    It 'should have valid JSON structure in each template' {
        $files = Get-ChildItem $templatesDir -Filter '*.json'
        $files.Count | Should -BeGreaterOrEqual 3

        foreach ($file in $files) {
            $content = Get-Content $file.FullName -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw -Because "$($file.Name) should be valid JSON"
        }
    }

    It 'should have required metadata fields' {
        $files = Get-ChildItem $templatesDir -Filter '*.json'
        foreach ($file in $files) {
            $tmpl = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $tmpl.metadata | Should -Not -BeNullOrEmpty
            $tmpl.metadata.standard | Should -Not -BeNullOrEmpty
            $tmpl.metadata.category | Should -Not -BeNullOrEmpty
            $tmpl.metadata.displayName | Should -Not -BeNullOrEmpty
        }
    }

    It 'should have at least one resourceType in each template' {
        $files = Get-ChildItem $templatesDir -Filter '*.json'
        foreach ($file in $files) {
            $tmpl = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $tmpl.resourceTypes.Count | Should -BeGreaterOrEqual 1
        }
    }

    It 'should have controls with required fields' {
        $files = Get-ChildItem $templatesDir -Filter '*.json'
        foreach ($file in $files) {
            $tmpl = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $tmpl.controls.Count | Should -BeGreaterOrEqual 1
            foreach ($ctrl in $tmpl.controls) {
                $ctrl.id | Should -Not -BeNullOrEmpty
                $ctrl.title | Should -Not -BeNullOrEmpty
                $ctrl.severity | Should -BeIn @('SHALL', 'SHOULD', 'MAY')
                $ctrl.resourceTypes | Should -Not -BeNullOrEmpty
            }
        }
    }

    It 'should only reference resource types listed in resourceTypes array' {
        $files = Get-ChildItem $templatesDir -Filter '*.json'
        foreach ($file in $files) {
            $tmpl = Get-Content $file.FullName -Raw | ConvertFrom-Json
            foreach ($ctrl in $tmpl.controls) {
                foreach ($rt in $ctrl.resourceTypes) {
                    $tmpl.resourceTypes | Should -Contain $rt -Because "Control $($ctrl.id) references '$rt' which should be in template resourceTypes"
                }
            }
        }
    }
}

Describe 'Add-TCMMonitorType' {
    It 'should exist as an exported function' {
        Get-Command Add-TCMMonitorType -Module EasyTCM | Should -Not -BeNullOrEmpty
    }

    It 'should require -Template or -TemplatePath' {
        { Add-TCMMonitorType -Force -ErrorAction Stop 2>$null } | Should -Throw
    }

    It 'should reject invalid template names' {
        { Add-TCMMonitorType -Template 'NonExistent-Template' -Force -ErrorAction Stop } | Should -Throw
    }
}


