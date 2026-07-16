#Requires -Version 5.1
<#
.SYNOPSIS
  Services, drivers with issues, startup commands, installed apps sample.
#>

function Invoke-ServiceDiagnostics {
  Write-Section "Services, drivers & startup"

  Write-Info "Automatic services not running:"
  Get-Service | Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' } |
    Select-Object Name, DisplayName, Status, StartType |
    Format-Table -AutoSize | Out-String | Write-Host

  Write-Info "Problem devices (ConfigManagerErrorCode != 0):"
  Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } |
    Select-Object Name, ConfigManagerErrorCode, Status, PNPDeviceID |
    Format-Table -AutoSize | Out-String | Write-Host

  Write-Info "Startup commands (HKLM/HKCU Run):"
  $runKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
  )
  foreach ($rk in $runKeys) {
    if (Test-Path $rk) {
      Write-Host "  $rk"
      Get-ItemProperty $rk | Select-Object * -ExcludeProperty PS* | Format-List | Out-String | Write-Host
    }
  }

  try {
    Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User |
      Format-Table -AutoSize | Out-String | Write-Host
  } catch {
    Write-Warn "StartupCommand WMI failed: $($_.Exception.Message)"
  }
}
