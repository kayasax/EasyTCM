# Changelog

All notable changes to EasyTCM will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
