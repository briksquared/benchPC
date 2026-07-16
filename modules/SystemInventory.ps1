#Requires -Version 5.1
<#
.SYNOPSIS
  System identity, OS, BIOS, motherboard, CPU, RAM snapshot.
#>

function Invoke-SystemInventory {
  Write-Section "System inventory"

  $cs = Get-CimInstance Win32_ComputerSystem
  $os = Get-CimInstance Win32_OperatingSystem
  $bios = Get-CimInstance Win32_BIOS
  $board = Get-CimInstance Win32_BaseBoard
  $cpu = Get-CimInstance Win32_Processor
  $tz = Get-TimeZone

  [pscustomobject]@{
    ComputerName     = $env:COMPUTERNAME
    UserName         = $env:USERNAME
    Manufacturer     = $cs.Manufacturer
    Model            = $cs.Model
    Domain           = $cs.Domain
    TotalPhysicalGB  = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    OS               = $os.Caption
    Version          = $os.Version
    Build            = $os.BuildNumber
    InstallDate      = $os.InstallDate
    LastBoot         = $os.LastBootUpTime
    UptimeHours      = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1)
    Architecture     = $os.OSArchitecture
    BIOS             = "$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)"
    BIOSDate         = $bios.ReleaseDate
    Board            = "$($board.Manufacturer) $($board.Product)"
    CPU              = ($cpu | ForEach-Object { $_.Name }) -join '; '
    LogicalProcessors= ($cpu | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    TimeZone         = $tz.Id
  } | Format-List | Out-String | Write-Host

  Write-Info "Pending reboot markers:"
  $rebootKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
    'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
  )
  $pending = $false
  foreach ($k in $rebootKeys) {
    if (Test-Path $k) { Write-Warn "Pending: $k"; $pending = $true }
  }
  if (-not $pending) { Write-Ok "No pending reboot markers found" }
}
