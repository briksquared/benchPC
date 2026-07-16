#Requires -Version 5.1
<#
.SYNOPSIS
  Windows-side stability fixes for benchPC (Event 41 / dirty shutdowns / services).
#>
$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$report = Join-Path $here 'reports\windows-stability-fix.txt'
New-Item -ItemType Directory -Force -Path (Join-Path $here 'reports') | Out-Null

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Log([string]$m) {
  $line = "$(Get-Date -Format o)  $m"
  Add-Content -Path $report -Value $line
  Write-Host $m
}

if (-not (Test-IsAdmin)) {
  Write-Host 'ERROR: Run elevated' -ForegroundColor Red
  exit 2
}

Set-Content -Path $report -Value "benchPC Windows stability fix $(Get-Date -Format o)"

# 1) Disable Fast Startup (Hiberboot) - major source of Kernel-Power 41 / dirty shutdown noise
try {
  Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 0 -Type DWord
  Log 'Disabled Fast Startup (HiberbootEnabled=0)'
} catch {
  Log "Fast Startup failed: $($_.Exception.Message)"
}

# 2) Active power scheme: reduce link-state / USB suspend weirdness on desktops
$scheme = (powercfg /getactivescheme) | Select-String 'GUID:\s*([a-f0-9\-]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
Log "Active scheme: $scheme"

# PCI Express Link State Power Management -> Off (0)
& powercfg /setacvalueindex $scheme SUB_PCIEXPRESS ASPM 0 | Out-Null
& powercfg /setdcvalueindex $scheme SUB_PCIEXPRESS ASPM 0 | Out-Null
Log 'PCI Express ASPM set to Off'

# USB selective suspend -> Disabled
& powercfg /setacvalueindex $scheme 2a206fd9-b0d2-4dd3-aecf-8145653d9a4e 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
& powercfg /setdcvalueindex $scheme 2a206fd9-b0d2-4dd3-aecf-8145653d9a4e 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
Log 'USB selective suspend disabled'

# Processor minimum state AC 5% is fine; ensure max 100%
& powercfg /setacvalueindex $scheme SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
& powercfg /setactive $scheme | Out-Null
Log 'Power scheme reapplied'

# 3) Ensure Windows Update stack can run (DISM hung earlier when stopped)
foreach ($s in @('bits','wuauserv','cryptsvc','DoSvc')) {
  try {
    Start-Service $s -ErrorAction SilentlyContinue
    $st = (Get-Service $s -ErrorAction SilentlyContinue).Status
    Log "Service $s = $st"
  } catch {
    Log "Service $s : $($_.Exception.Message)"
  }
}

# 4) Quick health verify after earlier repair
Log 'Running DISM CheckHealth...'
& dism.exe /Online /Cleanup-Image /CheckHealth
Log "DISM CheckHealth exit=$LASTEXITCODE"

# 5) Snapshot RAM speed (BIOS DOCP still required if 2133)
$ram = Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel, PartNumber, Speed, ConfiguredClockSpeed,
  @{N='GB';E={[math]::Round($_.Capacity/1GB,0)}}
$ram | Format-Table -AutoSize | Out-String | ForEach-Object { Log $_.TrimEnd() }
$spd = ($ram | Select-Object -First 1).ConfiguredClockSpeed
if ($spd -and $spd -lt 3000) {
  Log "RAM still at ${spd} MT/s - enable D.O.C.P in BIOS (use Open-UEFI-For-DOCP.bat)"
} else {
  Log "RAM speed looks profiled ($spd)"
}

# 6) Problem devices
$bad = Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
if ($bad) {
  Log 'Problem devices:'
  $bad | ForEach-Object { Log ("  - {0} (code {1})" -f $_.Name, $_.ConfigManagerErrorCode) }
} else {
  Log 'No PnP problem devices'
}

Log 'DONE'
Write-Host "Report: $report" -ForegroundColor Green
exit 0
