#Requires -Version 5.1
<#
.SYNOPSIS
  Guided repair menu for benchPC. Run as Administrator.
#>
[CmdletBinding()]
param(
  [ValidateSet('Menu','Safe','Full','Network','Cleanup','WUReset','DISM','SFC','MemTest')]
  [string]$Mode = 'Menu',
  [switch]$Yes
)

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'modules\Common.ps1')
. (Join-Path $here 'modules\RepairActions.ps1')

$ReportPath = New-BenchReportPath -Prefix 'repair'
Write-Host "benchPC repair" -ForegroundColor White
Write-Host "Report: $ReportPath"
if (-not (Test-IsAdmin)) {
  Write-Fail "Administrator required for most repair actions."
  if ($Mode -ne 'Cleanup') {
    throw "Elevate PowerShell and re-run."
  }
}

$transcribed = Start-TranscriptSafe -Path $ReportPath

function Show-Menu {
  Write-Section "Repair menu"
  Write-Host "  1) Safe pass     — temp cleanup + DISM CheckHealth + SFC"
  Write-Host "  2) Full repair   — DISM RestoreHealth + SFC + cleanup"
  Write-Host "  3) Network reset — winsock/IP/DNS (reboot after)"
  Write-Host "  4) Cleanup only  — temps + recycle bin"
  Write-Host "  5) WU reset      — Windows Update components"
  Write-Host "  6) DISM only"
  Write-Host "  7) SFC only"
  Write-Host "  8) Memory test   — schedule + reboot prompt"
  Write-Host "  9) Exit"
  return Read-Host "Select"
}

function Invoke-SafePass {
  Repair-TempCleanup
  if (Test-IsAdmin) {
    Write-Section "DISM CheckHealth"
    & dism.exe /Online /Cleanup-Image /CheckHealth
    Repair-SystemFiles
  }
}

function Invoke-FullPass {
  Repair-TempCleanup
  Repair-ComponentStore
  Repair-SystemFiles
}

try {
  $choice = $Mode
  if ($Mode -eq 'Menu') {
    switch (Show-Menu) {
      '1' { $choice = 'Safe' }
      '2' { $choice = 'Full' }
      '3' { $choice = 'Network' }
      '4' { $choice = 'Cleanup' }
      '5' { $choice = 'WUReset' }
      '6' { $choice = 'DISM' }
      '7' { $choice = 'SFC' }
      '8' { $choice = 'MemTest' }
      default { $choice = 'Exit' }
    }
  }

  switch ($choice) {
    'Safe'    { Invoke-SafePass }
    'Full'    {
      if (-not $Yes) {
        $c = Read-Host "Full repair can take a long time. Continue? (y/N)"
        if ($c -notmatch '^[Yy]') { Write-Info "Cancelled"; break }
      }
      Invoke-FullPass
    }
    'Network' {
      if (-not $Yes) {
        $c = Read-Host "Reset network stack? Reboot after. (y/N)"
        if ($c -notmatch '^[Yy]') { Write-Info "Cancelled"; break }
      }
      Repair-NetworkStack
    }
    'Cleanup' { Repair-TempCleanup }
    'WUReset' {
      if (-not $Yes) {
        $c = Read-Host "Reset Windows Update components? (y/N)"
        if ($c -notmatch '^[Yy]') { Write-Info "Cancelled"; break }
      }
      Repair-WindowsUpdateComponents
    }
    'DISM'    { Repair-ComponentStore }
    'SFC'     { Repair-SystemFiles }
    'MemTest' { Start-MemoryDiagnostic }
    default   { Write-Info "No action" }
  }

  Write-Section "Done"
  Write-Host "Report: $ReportPath" -ForegroundColor Green
}
finally {
  if ($transcribed) { Stop-TranscriptSafe }
}
