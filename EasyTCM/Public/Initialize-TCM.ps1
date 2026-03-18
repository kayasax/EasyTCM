function Initialize-TCM {
    <#
    .SYNOPSIS
        One-time setup: registers the TCM service principal and grants required permissions.
    .DESCRIPTION
        Automates the TCM onboarding process:
        1. Creates the TCM service principal (AppId 03b07b79-c5bc-4b5e-9bfa-13acf4a99998)
        2. Grants it the required Graph and workload permissions
        3. Validates the setup

        Requires: Connect-MgGraph with Application.ReadWrite.All and AppRoleAssignment.ReadWrite.All
    .PARAMETER TenantId
        The tenant ID to configure. If omitted, uses the current connection's tenant.
    .PARAMETER Workloads
        Which workloads to grant permissions for. Defaults to all — no reason to limit unless
        you have a specific compliance constraint.
    .PARAMETER SkipPermissionGrant
        Only create the service principal without granting permissions.
    .EXAMPLE
        Initialize-TCM
    .EXAMPLE
        # Limit to specific workloads (rare — only if needed for compliance)
        Initialize-TCM -Workloads Entra, Exchange
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$TenantId,

        [ValidateSet('All', 'Entra', 'Exchange', 'Intune', 'Teams', 'SecurityAndCompliance')]
        [string[]]$Workloads = @('All'),

        [switch]$SkipPermissionGrant
    )

    # Step 1: Create the TCM service principal
    Write-Host '[ 1/3 ] Registering TCM service principal...' -ForegroundColor Cyan

    $existingSp = $null
    try {
        $existingSp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$script:TCM_APP_ID'"
    }
    catch { Write-Debug "Service principal lookup failed: $_" }

    if ($existingSp.value -and $existingSp.value.Count -gt 0) {
        $tcmSp = $existingSp.value[0]
        Write-Host "  TCM service principal already exists (ObjectId: $($tcmSp.id))" -ForegroundColor Green
    }
    else {
        if ($PSCmdlet.ShouldProcess('TCM Service Principal', 'Create')) {
            $body = @{ appId = $script:TCM_APP_ID } | ConvertTo-Json
            $tcmSp = Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals' -Body $body -ContentType 'application/json'
            Write-Host "  Created TCM service principal (ObjectId: $($tcmSp.id))" -ForegroundColor Green
        }
    }

    if ($SkipPermissionGrant) {
        Write-Host '[ SKIP ] Permission grant skipped.' -ForegroundColor Yellow
        return [PSCustomObject]@{
            ServicePrincipalId = $tcmSp.id
            AppId              = $script:TCM_APP_ID
            PermissionsGranted = $false
            Status             = 'ServicePrincipalCreated'
        }
    }

    # Step 2: Grant permissions
    Write-Host '[ 2/3 ] Granting permissions to TCM service principal...' -ForegroundColor Cyan

    # Get Microsoft Graph service principal
    $graphSp = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'").value[0]

    # Define role mappings per workload
    $permissionsByWorkload = @{
        'Entra'                  = @('User.Read.All', 'Policy.Read.All', 'Policy.ReadWrite.ConditionalAccess', 'RoleManagement.Read.Directory', 'Application.Read.All', 'Group.Read.All')
        'Exchange'               = @('Organization.Read.All')
        'Intune'                 = @('DeviceManagementConfiguration.Read.All')
        'Teams'                  = @('Organization.Read.All')
        'SecurityAndCompliance'  = @('Organization.Read.All')  # Also requires Compliance Administrator directory role
    }

    $targetWorkloads = if ($Workloads -contains 'All') { $permissionsByWorkload.Keys } else { $Workloads }

    $allRoles = $targetWorkloads | ForEach-Object { $permissionsByWorkload[$_] } | Select-Object -Unique

    $grantedCount = 0
    foreach ($roleName in $allRoles) {
        $appRole = $graphSp.appRoles | Where-Object { $_.value -eq $roleName -and $_.allowedMemberTypes -contains 'Application' }
        if (-not $appRole) {
            Write-Warning "  App role '$roleName' not found on Microsoft Graph SP — skipping"
            continue
        }

        # Check if already assigned
        $existing = $null
        try {
            $existing = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($tcmSp.id)/appRoleAssignments?`$filter=appRoleId eq '$($appRole.id)'"
        }
        catch { Write-Debug "App role assignment lookup failed: $_" }

        if ($existing.value -and $existing.value.Count -gt 0) {
            Write-Host "  Permission '$roleName' already granted" -ForegroundColor DarkGray
            continue
        }

        if ($PSCmdlet.ShouldProcess($roleName, 'Grant to TCM SP')) {
            $assignBody = @{
                principalId = $tcmSp.id
                resourceId  = $graphSp.id
                appRoleId   = $appRole.id
            } | ConvertTo-Json

            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($tcmSp.id)/appRoleAssignments" -Body $assignBody -ContentType 'application/json' | Out-Null
            Write-Host "  Granted '$roleName'" -ForegroundColor Green
            $grantedCount++
        }
    }

    # Grant Exchange.ManageAsApp for SecurityAndCompliance workload
    if ($targetWorkloads -contains 'SecurityAndCompliance') {
        Write-Host '  Granting Exchange.ManageAsApp for Security & Compliance...' -ForegroundColor Cyan
        $exoSp = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '00000002-0000-0ff1-ce00-000000000000'").value[0]
        $manageAsApp = $exoSp.appRoles | Where-Object { $_.value -eq 'Exchange.ManageAsApp' }
        if ($manageAsApp) {
            $existingExo = $null
            try { $existingExo = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($tcmSp.id)/appRoleAssignments?`$filter=appRoleId eq '$($manageAsApp.id)'" } catch { }
            if ($existingExo.value -and $existingExo.value.Count -gt 0) {
                Write-Host "  Exchange.ManageAsApp already granted" -ForegroundColor DarkGray
            }
            elseif ($PSCmdlet.ShouldProcess('Exchange.ManageAsApp', 'Grant to TCM SP')) {
                $exoBody = @{ principalId = $tcmSp.id; resourceId = $exoSp.id; appRoleId = $manageAsApp.id } | ConvertTo-Json
                Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($tcmSp.id)/appRoleAssignments" -Body $exoBody -ContentType 'application/json' | Out-Null
                Write-Host "  Granted 'Exchange.ManageAsApp'" -ForegroundColor Green
                $grantedCount++
            }
        }

        # Assign Compliance Administrator directory role
        Write-Host '  Assigning Compliance Administrator role...' -ForegroundColor Cyan
        $dirRoles = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directoryRoles"
        $compAdmin = $dirRoles.value | Where-Object { $_.displayName -eq 'Compliance Administrator' }
        if (-not $compAdmin) {
            $templates = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directoryRoleTemplates"
            $compTemplate = $templates.value | Where-Object { $_.displayName -eq 'Compliance Administrator' }
            if ($compTemplate) {
                $compAdmin = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/directoryRoles" -Body (@{ roleTemplateId = $compTemplate.id } | ConvertTo-Json) -ContentType 'application/json'
            }
        }
        if ($compAdmin) {
            $memberCheck = $null
            try { $memberCheck = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directoryRoles/$($compAdmin.id)/members?`$filter=id eq '$($tcmSp.id)'" } catch { }
            if ($memberCheck.value -and $memberCheck.value.Count -gt 0) {
                Write-Host "  Compliance Administrator already assigned" -ForegroundColor DarkGray
            }
            elseif ($PSCmdlet.ShouldProcess('Compliance Administrator', 'Assign to TCM SP')) {
                $refBody = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($tcmSp.id)" } | ConvertTo-Json
                Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/directoryRoles/$($compAdmin.id)/members/`$ref" -Body $refBody -ContentType 'application/json' | Out-Null
                Write-Host "  Assigned 'Compliance Administrator' directory role" -ForegroundColor Green
            }
        }
        else {
            Write-Warning "  Could not find or activate 'Compliance Administrator' directory role"
        }
    }

    # Step 3: Validate
    Write-Host '[ 3/3 ] Validating setup...' -ForegroundColor Cyan
    $validation = Test-TCMConnection -Quiet

    $result = [PSCustomObject]@{
        ServicePrincipalId = $tcmSp.id
        AppId              = $script:TCM_APP_ID
        PermissionsGranted = $true
        NewPermissions     = $grantedCount
        Workloads          = $targetWorkloads
        Validated          = $validation
        Status             = if ($validation) { 'Ready' } else { 'SetupCompleteValidationFailed' }
    }

    if ($validation) {
        Write-Host "`nTCM setup complete! You can now create monitors and snapshots." -ForegroundColor Green
    }
    else {
        Write-Warning "`nTCM service principal created and permissions granted, but API validation failed. Permissions may take a few minutes to propagate."
    }

    $result
}
