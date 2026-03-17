# Contributing to EasyTCM

First off — thank you for considering a contribution! EasyTCM is a community project and every contribution helps make M365 configuration management more accessible.

## Ways to Contribute

| Contribution | Difficulty | Impact |
|---|---|---|
| Report a bug | Easy | High |
| Suggest a feature | Easy | Medium |
| Submit a baseline template (CIS/CISA) | Medium | Very High |
| Fix a bug | Medium | High |
| Add a new cmdlet | Medium-Hard | High |
| Improve documentation | Easy | High |

## Quick Start for Development

```powershell
# 1. Fork and clone
git clone https://github.com/<your-username>/EasyTCM.git
cd EasyTCM

# 2. Create a branch
git checkout -b feature/my-improvement

# 3. Import the module in dev mode
Import-Module ./EasyTCM/EasyTCM.psd1 -Force

# 4. Make your changes and test
Invoke-Pester ./tests/

# 5. Run the linter
Install-Module PSScriptAnalyzer -Force
Invoke-ScriptAnalyzer -Path ./EasyTCM -Recurse -Settings PSGallery

# 6. Commit and push
git add -A
git commit -m "feat: description of your change"
git push origin feature/my-improvement

# 7. Open a PR
```

## Project Structure

```
EasyTCM/
├── EasyTCM/
│   ├── EasyTCM.psd1              # Module manifest
│   ├── EasyTCM.psm1              # Module loader (dot-sources Public + Private)
│   ├── Public/                    # Exported cmdlets (one file per cmdlet)
│   │   ├── Initialize-TCM.ps1
│   │   ├── New-TCMSnapshot.ps1
│   │   ├── Sync-TCMDriftToMaester.ps1
│   │   └── ...
│   └── Private/                   # Internal helpers (not exported)
│       ├── Invoke-TCMGraphRequest.ps1
│       └── Get-TCMWorkloadResources.ps1
├── tests/
│   └── EasyTCM.Tests.ps1
├── templates/                     # Baseline templates (CIS, CISA, etc.)
├── docs/
│   ├── GETTING-STARTED.md
│   ├── VISION.md
│   └── MAESTER-BRIDGE.md
└── .github/
    ├── workflows/
    │   ├── ci.yml                 # Lint + test on push
    │   └── publish.yml            # PSGallery publish on release
    └── ISSUE_TEMPLATE/
```

## Coding Standards

### Cmdlet Pattern
Every public cmdlet follows this structure:
- **One file per cmdlet** in `EasyTCM/Public/`
- **Verb-TCM\<Noun\>** naming convention
- **Comment-based help** with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`
- **`SupportsShouldProcess`** for any mutating operations
- All Graph API calls go through `Invoke-TCMGraphRequest` (private helper)

### Example
```powershell
function Get-TCMExample {
    <#
    .SYNOPSIS
        Brief description.
    .DESCRIPTION
        Longer description.
    .PARAMETER Id
        The resource ID.
    .EXAMPLE
        Get-TCMExample -Id 'abc123'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    Invoke-TCMGraphRequest -Endpoint "examples/$Id"
}
```

### Do's and Don'ts

| Do | Don't |
|---|---|
| Use `Invoke-TCMGraphRequest` for API calls | Call `Invoke-MgGraphRequest` directly in public cmdlets |
| Use `Write-Host` with colors for user feedback | Use `Write-Output` for status messages |
| Add `[CmdletBinding()]` to every function | Use positional parameters without names |
| Add Pester tests for new cmdlets | Ship without any test coverage |
| Follow PowerShell naming conventions | Invent non-standard verb prefixes |

## Baseline Template Contributions

Baseline templates are high-impact contributions! To submit one:

1. Create a JSON file in `templates/` following the TCM baseline format
2. Map it to a specific standard (CIS section numbers, CISA SCuBA controls)
3. Document which workloads and resource types it covers
4. Test it with `New-TCMMonitor -BaselinePath ./templates/your-template.json`
5. Open a PR using the Baseline Template issue template

## Testing

```powershell
# Run all tests
Invoke-Pester ./tests/ -Output Detailed

# Run specific tests
Invoke-Pester ./tests/ -Filter "ConvertTo-TCMBaseline"
```

For integration tests (requires a real tenant):
- Set `$env:TCM_TENANT_ID` to your test tenant
- Tests tagged `Integration` will connect and validate against the live API

## Questions?

- Open a [Discussion](https://github.com/kayasax/EasyTCM/discussions)
- Check existing [Issues](https://github.com/kayasax/EasyTCM/issues)
- Read the [Getting Started guide](docs/GETTING-STARTED.md)
