#Requires -Version 5.1
<#
.SYNOPSIS
  Aggressive but safe Windows repair pass after deep dive.
#>
$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = Join-Path $here 'reports\deep-repair.log'
New-Item -ItemType Directory -Force -Path (Join-Path $here 'reports') | Out-Null
Start-Transcript -Path $log -Force | Out-Null

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Log($m){ Write-Host $m }

try {
  if (-not (Test-IsAdmin)) { Log 'ERROR not admin'; exit 2 }
  Log "Deep repair start $(Get-Date -Format o)"

  # Keep Fast Startup off
  Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 0 -Type DWord -Force
  Log 'Fast Startup confirmed off'

  # Crash dumps: complete memory dump can be huge; use automatic
  New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Force | Out-Null
  Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Name CrashDumpEnabled -Value 3 -Type DWord
  Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Name AutoReboot -Value 1 -Type DWord
  Log 'CrashControl: Automatic dump enabled'

  # Power / PCIe / USB (desktop stability)
  $scheme = ((powercfg /getactivescheme) | Select-String 'GUID:\s*([a-f0-9\-]+)').Matches[0].Groups[1].Value
  powercfg /setacvalueindex $scheme SUB_PCIEXPRESS ASPM 0 | Out-Null
  powercfg /setdcvalueindex $scheme SUB_PCIEXPRESS ASPM 0 | Out-Null
  powercfg /setacvalueindex $scheme 2a206fd9-b0d2-4dd3-aecf-8145653d9a4e 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
  powercfg /setdcvalueindex $scheme 2a206fd9-b0d2-4dd3-aecf-8145653d9a4e 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
  # Disable PCIe power management via legacy alias if present
  powercfg /change standby-timeout-ac 0 | Out-Null
  powercfg /change monitor-timeout-ac 30 | Out-Null
  powercfg /setactive $scheme | Out-Null
  Log "Power scheme tuned: $scheme"

  # Network soft repair (no winsock reset - avoids forced reboot mid-session)
  ipconfig /flushdns | Out-Null
  Clear-DnsClientCache -ErrorAction SilentlyContinue
  netsh int ip reset | Out-Null
  netsh winhttp reset proxy | Out-Null
  Log 'Network soft reset done'

  # Windows Update stack
  foreach ($s in @('bits','wuauserv','cryptsvc','DoSvc','UsoSvc','WaaSMedicSvc')) {
    try { Start-Service $s -ErrorAction SilentlyContinue; Log "Service $s=$((Get-Service $s -EA SilentlyContinue).Status)" } catch { Log "Service $s skip" }
  }

  # Component store verify + SFC verifyonly then scannow if needed
  Log 'DISM CheckHealth'
  dism /Online /Cleanup-Image /CheckHealth
  Log "CheckHealth=$LASTEXITCODE"
  Log 'DISM ScanHealth (can take a while)'
  dism /Online /Cleanup-Image /ScanHealth
  $scan = $LASTEXITCODE
  Log "ScanHealth=$scan"
  # CheckHealth/ScanHealth often return 0 even when store is "repairable" - always RestoreHealth in deep pass
  Log 'DISM RestoreHealth'
  dism /Online /Cleanup-Image /RestoreHealth
  Log "RestoreHealth=$LASTEXITCODE"
  Log 'SFC scannow'
  sfc /scannow
  Log "SFC=$LASTEXITCODE"

  # Disk: online scan status + schedule CHKDSK spotfix if dirty
  Log 'chkntfs C:'
  chkntfs C:
  # Repair volume online if supported (Windows 8+)
  try {
    Repair-Volume -DriveLetter C -Scan -ErrorAction Stop | Out-String | Write-Host
    Log 'Repair-Volume -Scan C: done'
  } catch { Log "Repair-Volume: $($_.Exception.Message)" }

  # Rebuild icon/performance caches lightly
  try {
    ie4uinit.exe -show 2>$null
  } catch {}

  # Disable unnecessary delayed auto-start flapping: ensure SysMain running if present
  foreach ($s in @('SysMain','EventLog','Schedule','BrokerInfrastructure','Power')) {
    try { Set-Service $s -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service $s -ErrorAction SilentlyContinue } catch {}
  }

  # NVIDIA display power - ensure GPU device started
  Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | Where-Object Status -ne 'OK' | ForEach-Object {
    Log "Display device bad: $($_.FriendlyName) $($_.Status)"
    try { Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue } catch {}
  }

  # Temp cleanup (non-fatal)
  foreach ($t in @($env:TEMP, "$env:SystemRoot\Temp")) {
    if (Test-Path $t) {
      Get-ChildItem $t -Force -EA SilentlyContinue | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -EA SilentlyContinue
      }
      Log "Cleaned $t"
    }
  }

  # Write findings marker for DOCP
  $ram = (Get-CimInstance Win32_PhysicalMemory | Select-Object -First 1).ConfiguredClockSpeed
  Log "RAM ConfiguredClockSpeed=$ram"
  if ($ram -lt 3000) {
    Log 'ACTION REQUIRED: Run Open-UEFI-For-DOCP.bat to enable D.O.C.P 3200'
    Set-Content (Join-Path $here 'reports\NEEDS-DOCP.txt') "RAM at $ram MT/s - enable D.O.C.P then reboot"
  }

  Log "Deep repair DONE $(Get-Date -Format o)"
  exit 0
}
finally {
  try { Stop-Transcript | Out-Null } catch {}
}
