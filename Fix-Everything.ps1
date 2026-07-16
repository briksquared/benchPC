#Requires -Version 5.1
<#
.SYNOPSIS
  Non-interactive elevated repair pass for benchPC "fix everything".
#>
$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

$log = Join-Path $here 'reports\fix-everything.log'
New-Item -ItemType Directory -Force -Path (Join-Path $here 'reports') | Out-Null
Start-Transcript -Path $log -Force | Out-Null

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

try {
  Write-Host "benchPC Fix-Everything starting $(Get-Date -Format o)"
  if (-not (Test-IsAdmin)) {
    Write-Host "ERROR: Not elevated" -ForegroundColor Red
    exit 2
  }

  Write-Host "`n=== Temp cleanup ===" -ForegroundColor Cyan
  foreach ($t in @($env:TEMP, (Join-Path $env:SystemRoot 'Temp'), (Join-Path $env:LOCALAPPDATA 'Temp'))) {
    if (-not (Test-Path $t)) { continue }
    Write-Host "Cleaning $t"
    Get-ChildItem -Path $t -Force -ErrorAction SilentlyContinue | ForEach-Object {
      try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop } catch {}
    }
  }
  try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch {}

  Write-Host "`n=== DNS / ARP flush ===" -ForegroundColor Cyan
  ipconfig /flushdns | Out-Host
  try { Clear-DnsClientCache -ErrorAction SilentlyContinue } catch {}

  Write-Host "`n=== DISM RestoreHealth ===" -ForegroundColor Cyan
  & dism.exe /Online /Cleanup-Image /RestoreHealth
  $dismExit = $LASTEXITCODE
  Write-Host "DISM exit: $dismExit"

  Write-Host "`n=== SFC /scannow ===" -ForegroundColor Cyan
  & sfc.exe /scannow
  $sfcExit = $LASTEXITCODE
  Write-Host "SFC exit: $sfcExit"

  Write-Host "`n=== Component store cleanup ===" -ForegroundColor Cyan
  & dism.exe /Online /Cleanup-Image /StartComponentCleanup
  $cleanupExit = $LASTEXITCODE
  Write-Host "Component cleanup exit: $cleanupExit"

  Write-Host "`n=== Windows Update service health ===" -ForegroundColor Cyan
  foreach ($s in @('wuauserv','bits','cryptsvc')) {
    try {
      Start-Service -Name $s -ErrorAction SilentlyContinue
      Write-Host "Service $s : $((Get-Service $s).Status)"
    } catch {
      Write-Host "Service $s issue: $($_.Exception.Message)"
    }
  }

  Write-Host "`n=== Soft network repair (no winsock reset) ===" -ForegroundColor Cyan
  & netsh.exe int ip reset | Out-Host
  & netsh.exe winhttp reset proxy | Out-Host

  Write-Host "`n=== Volume dirty-bit check (C:) ===" -ForegroundColor Cyan
  & chkntfs.exe C: | Out-Host

  Write-Host "`n=== System restore / volume shadow (info) ===" -ForegroundColor Cyan
  try {
    Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Select-Object -Last 3 |
      Format-Table -AutoSize | Out-String | Write-Host
  } catch {
    Write-Host "Restore points unavailable: $($_.Exception.Message)"
  }

  Write-Host "`n=== Summary ===" -ForegroundColor Green
  Write-Host "DISM=$dismExit SFC=$sfcExit Cleanup=$cleanupExit"
  Write-Host "Log: $log"
  Write-Host "DONE $(Get-Date -Format o)"
  exit 0
}
finally {
  try { Stop-Transcript | Out-Null } catch {}
}
