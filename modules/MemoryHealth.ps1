#Requires -Version 5.1
<#
.SYNOPSIS
  Memory modules, page file, and optional MDSched prompt.
#>

function Invoke-MemoryDiagnostics {
  Write-Section "Memory"

  Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel, Manufacturer, PartNumber,
    @{N='CapacityGB';E={[math]::Round($_.Capacity/1GB,2)}}, Speed, ConfiguredClockSpeed, DeviceLocator |
    Format-Table -AutoSize | Out-String | Write-Host

  $os = Get-CimInstance Win32_OperatingSystem
  Write-Host ("Free physical: {0:N2} GB / {1:N2} GB" -f ($os.FreePhysicalMemory/1MB), ($os.TotalVisibleMemorySize/1MB))
  Write-Host ("Free virtual:  {0:N2} GB / {1:N2} GB" -f ($os.FreeVirtualMemory/1MB), ($os.TotalVirtualMemorySize/1MB))

  Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage |
    Format-Table -AutoSize | Out-String | Write-Host

  $memEvents = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-MemoryDiagnostics-Results'; StartTime=(Get-Date).AddDays(-90)} -ErrorAction SilentlyContinue |
    Select-Object -First 5 TimeCreated, Id, LevelDisplayName, Message
  if ($memEvents) {
    Write-Info "Recent Memory Diagnostics results:"
    $memEvents | Format-List | Out-String | Write-Host
  } else {
    Write-Info "No Memory Diagnostics results in the last 90 days."
  }
}
