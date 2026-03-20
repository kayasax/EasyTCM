# Changelog

All notable changes to EasyTCM will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] - 2026-03-20

### Changed
- **Renamed `Watch-TCMDrift` to `Show-TCMDrift`** — uses an approved PowerShell verb, eliminates import warning

### Fixed
- `Show-TCMDrift -Report` and `-Maester` modes now show a brief drift summary in the console before generating output, so users aren't blind to active drifts
- HTML report timestamp was using local time but labeled as UTC — now uses actual UTC

## [0.3.0] - 2026-03-19

### Added
- **`Start-TCMMonitoring`** — Guided setup wizard: from zero to monitoring in a single command. Handles Graph connection, service principal setup, snapshot, baseline conversion, and monitor creation with a 5-step interactive flow.
- **`Show-TCMDrift`** — Daily drift check with three modes: console summary (default), HTML report (`-Report`), or Maester test results (`-Maester`). Includes `-CompareBaseline` to detect new/deleted resources and `-PassThru` for pipeline integration.
- **`Update-TCMBaseline`** — Rebaseline after approved changes: takes a fresh snapshot, converts to baseline with the same profile, updates the monitor, and clears all previous drift records. Shows current drift for review before proceeding.
- **`Compare-TCMBaseline`** — file-based cache (`%TEMP%\EasyTCM-CompareBaselineCache.json`) that survives `Import-Module -Force` and session restarts (1-hour TTL)
- **Maester test generation** — `Sync-TCMDriftToMaester` now generates `TCM-Drift.Tests.ps1` per drift suite with `Add-MtTestResultDetail` for proper Maester report formatting (markdown tables with property diffs)
- **GitHub Pages documentation site** — narrative docs covering the tenant drift problem, monitoring profiles, Maester integration, and continuous monitoring lifecycle

### Fixed
- Unit tests renamed from `.Tests.ps1` to `.test.ps1` to prevent Maester discovery
- `Get-Module EasyTCM` double-module bug fixed with `Select-Object -First 1`
- Variable escaping in generated Maester test templates — switched from string interpolation to `-f` format operator
- `$baseline.Count` showing type name instead of count in generated tests

### Changed
- Module version: 0.2.0 → 0.3.0
- Exported cmdlets: 16 → 19

## [0.2.0] - 2026-03-18

### Added
- **Security & Compliance workload** — 24 new resource types including DLP policies, retention policies, sensitivity labels, compliance tags, case holds, and supervisory review
- Display name validation in `New-TCMSnapshot` — API now rejects non-alphanumeric characters (only letters, numbers, and spaces allowed)
- `Initialize-TCM` auto-grants `Exchange.ManageAsApp` and `Compliance Administrator` directory role for SC workload
- Recommended monitoring profile expanded with 3 additional SC types: `dlpcompliancerule`, `retentioncompliancerule`, `compliancetag` (now 30 types)
- `Get-TCMMonitor` now shows baseline summary by default: resource count, workload breakdown, and monitored types — answers "what am I monitoring?" at a glance
- New `MonitoredTypes` property on monitor output — pipe to `Select-Object -ExpandProperty MonitoredTypes` for the full list
- `-SkipBaseline` switch on `Get-TCMMonitor` for raw API output without baseline fetch

### Changed
- Total validated resource types: 38 → 62 across 5 workloads (was 4)
- `New-TCMSnapshot`, `Get-TCMDrift`, `Initialize-TCM` now accept `SecurityAndCompliance` workload
- Recommended profile: 27 → 30 types (6 SC types total)

## [0.1.0] - 2026-03-17

### Added — Initial Preview Release

#### Setup & Authentication
- `Initialize-TCM` — One-command TCM service principal registration with automatic permission grants for selected workloads
- `Test-TCMConnection` — Validate Graph connection, TCM SP existence, and API reachability

#### Snapshots
- `New-TCMSnapshot` — Create snapshot jobs with workload shortcuts (Entra, Exchange, etc.) and optional `-Wait` polling
- `Get-TCMSnapshot` — Retrieve snapshot jobs with optional content download (`-IncludeContent`)
- `Remove-TCMSnapshot` — Delete snapshot jobs with confirmation
- `ConvertTo-TCMBaseline` — **Key feature**: Convert a snapshot into a monitor baseline, enabling the Snap → Monitor flow

#### Monitors
- `New-TCMMonitor` — Create monitors with quota-aware daily cost warnings
- `Get-TCMMonitor` — List/get monitors with optional baseline retrieval
- `Update-TCMMonitor` — Update monitors with ConfirmImpact warning about drift deletion
- `Remove-TCMMonitor` — Delete monitors with confirmation

#### Drift Detection
- `Get-TCMDrift` — Enriched drift results with workload classification, filtering by monitor/status/workload
- `Get-TCMMonitoringResult` — Per-monitor cycle results
- `Get-TCMQuota` — Real-time quota dashboard (monitors, daily resources, snapshots)

#### Maester Bridge (North Star)
- `Sync-TCMDriftToMaester` — Convert TCM active drifts into Maester-compatible drift test suites (baseline.json + current.json + .Tests.ps1), solving Maester's state management challenge with server-side TCM monitoring

#### Internal
- `Invoke-TCMGraphRequest` — Graph API wrapper with pagination, error handling
- `Get-TCMWorkloadResources` — Workload-to-resource-type mapping for all 6 workloads

#### Infrastructure
- Module manifest (`EasyTCM.psd1`) with 14 exported functions
- GitHub Actions CI (PSScriptAnalyzer + Pester)
- GitHub Actions PSGallery publish on release
- Issue templates (Bug, Feature Request, Baseline Template)
- PR template
- Getting Started guide
- Product vision and launch plan
- CONTRIBUTING.md
