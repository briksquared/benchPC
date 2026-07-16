#Requires -Version 5.1
<#
.SYNOPSIS
  Full read-mostly diagnostics for this bench PC. Prefer elevated PowerShell.
#>
[CmdletBinding()]
param(
  [switch]$SkipNetworkPing,
  [string]$ReportPath
)

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'modules\Common.ps1')
. (Join-Path $here 'modules\SystemInventory.ps1')
. (Join-Path $here 'modules\DiskHealth.ps1')
. (Join-Path $here 'modules\MemoryHealth.ps1')
. (Join-Path $here 'modules\NetworkHealth.ps1')
. (Join-Path $here 'modules\EventHealth.ps1')
. (Join-Path $here 'modules\ServicesStartup.ps1')
. (Join-Path $here 'modules\UpdateHealth.ps1')
. (Join-Path $here 'modules\Performance.ps1')

if (-not $ReportPath) {
  $ReportPath = New-BenchReportPath -Prefix 'full-diag'
}

Write-Host "benchPC full diagnostics" -ForegroundColor White
Write-Host "Report: $ReportPath"
if (-not (Test-IsAdmin)) {
  Write-Warn "Not running as Administrator — some checks will be limited."
}

$transcribed = Start-TranscriptSafe -Path $ReportPath

try {
  Invoke-SystemInventory
  Invoke-PerformanceDiagnostics
  Invoke-DiskDiagnostics
  Invoke-MemoryDiagnostics
  if (-not $SkipNetworkPing) {
    Invoke-NetworkDiagnostics
  } else {
    Write-Section "Network (skipped)"
  }
  Invoke-ServiceDiagnostics
  Invoke-EventDiagnostics
  Invoke-UpdateDiagnostics

  Write-Section "Done"
  Write-Ok "Full diagnostics finished"
  Write-Host "Report saved to: $ReportPath" -ForegroundColor Green
  Write-Host "Next: .\Run-Repair.ps1  (admin recommended)" -ForegroundColor Gray
}
finally {
  if ($transcribed) { Stop-TranscriptSafe }
}
