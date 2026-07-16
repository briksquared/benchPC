#Requires -Version 5.1
<#
.SYNOPSIS
  Continue hardening: Wi-Fi power, TRIM, startup cleanup, crash dumps verify.
#>
$ErrorActionPreference = 'Continue'
$here = 'C:\Users\briks\Desktop\benchPC'
$log = Join-Path $here 'reports\continue-hardening.log'
New-Item -ItemType Directory -Force -Path (Join-Path $here 'reports') | Out-Null
Start-Transcript $log -Force | Out-Null

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

try {
  if (-not (Test-IsAdmin)) { throw 'admin required' }
  Write-Host "Hardening $(Get-Date -Format o)"

  # Fast Startup stay off
  Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0 -Type DWord -Force

  # Crash dumps
  Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Name CrashDumpEnabled -Value 3 -Type DWord -Force
  Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -Name AutoReboot -Value 1 -Type DWord -Force

  # Wi-Fi: disable power saving on Intel AX200
  Get-NetAdapter -Name 'Wi-Fi' -EA SilentlyContinue | ForEach-Object {
    Write-Host "Wi-Fi adapter $($_.Name) $($_.Status)"
    try {
      Set-NetAdapterPowerManagement -Name $_.Name -AllowComputerToTurnOffDevice Disabled -ErrorAction SilentlyContinue
      Write-Host 'Set-NetAdapterPowerManagement AllowComputerToTurnOffDevice=Disabled'
    } catch { Write-Host $_ }
  }
  # Device manager power mgmt via PnP for Wi-Fi
  Get-PnpDevice -Class Net -EA SilentlyContinue | Where-Object { $_.FriendlyName -match 'Wi-Fi|AX200|Wireless' -and $_.Status -eq 'OK' } | ForEach-Object {
    Write-Host "Net device: $($_.FriendlyName)"
  }

  # Advanced Wi-Fi properties via netsh (LSO-related stability)
  netsh wlan set profileorder | Out-Null
  # Disable Wi-Fi Sense-like / power - use powercfg wireless adapter setting Off
  $scheme = ((powercfg /getactivescheme) | Select-String 'GUID:\s*([a-f0-9\-]+)').Matches[0].Groups[1].Value
  # Wireless Adapter Settings -> Power Saving Mode -> Maximum Performance (0)
  powercfg /setacvalueindex $scheme 19cbb8fa-5279-450e-9fac-8a3d5eda7335 12bbebe6-58d6-4636-95bb-3217ef867c1a 0
  powercfg /setdcvalueindex $scheme 19cbb8fa-5279-450e-9fac-8a3d5eda7335 12bbebe6-58d6-4636-95bb-3217ef867c1a 0
  powercfg /setactive $scheme
  Write-Host 'Wireless adapter power saving = Max Performance'

  # PCIe ASPM off + USB selective suspend off (reaffirm)
  powercfg /setacvalueindex $scheme SUB_PCIEXPRESS ASPM 0
  powercfg /setdcvalueindex $scheme SUB_PCIEXPRESS ASPM 0
  powercfg /setacvalueindex $scheme 2a206fd9-b0d2-4dd3-aecf-8145653d9a4e 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
  powercfg /setdcvalueindex $scheme 2a206fd9-b0d2-4dd3-aecf-8145653d9a4e 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
  powercfg /setactive $scheme

  # TRIM SSD
  Write-Host 'Running Optimize-Volume C Retrim...'
  Optimize-Volume -DriveLetter C -ReTrim -Verbose
  Write-Host 'TRIM done'

  # Remove stability-risk startup entries (not uninstalling apps)
  $hkcuRun = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
  foreach ($name in @('CCleaner Smart Cleaning','RazerCortex')) {
    if (Get-ItemProperty -Path $hkcuRun -Name $name -EA SilentlyContinue) {
      Remove-ItemProperty -Path $hkcuRun -Name $name -Force
      Write-Host "Removed HKCU Run: $name"
    }
  }
  $hklmRun = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
  if (Get-ItemProperty -Path $hklmRun -Name 'RazerCortex' -EA SilentlyContinue) {
    Remove-ItemProperty -Path $hklmRun -Name 'RazerCortex' -Force
    Write-Host 'Removed HKLM Run: RazerCortex'
  }

  # Ensure YellowStar stays gone
  $ys = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\YellowStar.exe'
  if (Test-Path $ys) { Remove-Item $ys -Force; Write-Host 'Removed YellowStar again' } else { Write-Host 'YellowStar absent OK' }

  # Disable indexing on F: to reduce IO stress on failing disk
  try {
    $f = New-Object -ComObject Shell.Application
    # attrib +I via fsutil / path
    cmd /c 'attrib +I F:\ /S /D' | Out-Null
    Write-Host 'Marked F: contents not-content-indexed (best effort)'
  } catch { Write-Host "index skip: $_" }
  # Volume attribute via Disable-WindowsOptionalFeature is wrong; use:
  try {
    $vol = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter='F:'"
    if ($vol) {
      $vol | Set-CimInstance -Property @{ IndexingEnabled = $false } -EA SilentlyContinue
      Write-Host 'IndexingEnabled=false on F:'
    }
  } catch { Write-Host "F index: $($_.Exception.Message)" }

  # Start WU services
  foreach ($s in @('bits','wuauserv','cryptsvc','DoSvc')) { Start-Service $s -EA SilentlyContinue }

  # Quick DISM checkhealth
  dism /Online /Cleanup-Image /CheckHealth
  Write-Host "CheckHealth=$LASTEXITCODE"

  Write-Host "HARDENING DONE $(Get-Date -Format o)"
}
finally { Stop-Transcript | Out-Null }
