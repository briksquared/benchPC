#Requires -Version 5.1
<#
.SYNOPSIS
  Performance snapshot: CPU, GPU, thermal-ish, top processes, battery if laptop.
#>

function Invoke-PerformanceDiagnostics {
  Write-Section "Performance snapshot"

  $cpu = Get-CimInstance Win32_Processor
  foreach ($c in $cpu) {
    Write-Host ("CPU load: {0}% — {1}" -f $c.LoadPercentage, $c.Name)
  }

  Get-CimInstance Win32_OperatingSystem | ForEach-Object {
    $used = ($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) / $_.TotalVisibleMemorySize * 100
    Write-Host ("RAM used: {0:N1}%" -f $used)
  }

  Write-Info "Top CPU processes:"
  Get-Process | Sort-Object CPU -Descending | Select-Object -First 12 Name, Id,
    @{N='CPU(s)';E={[math]::Round($_.CPU,1)}},
    @{N='WS(MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}} |
    Format-Table -AutoSize | Out-String | Write-Host

  Write-Info "Top memory processes:"
  Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 12 Name, Id,
    @{N='WS(MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}},
    @{N='CPU(s)';E={[math]::Round($_.CPU,1)}} |
    Format-Table -AutoSize | Out-String | Write-Host

  try {
    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if ($battery) {
      $battery | Select-Object Name, EstimatedChargeRemaining, BatteryStatus, DesignVoltage |
        Format-Table -AutoSize | Out-String | Write-Host
    }
  } catch { }

  Write-Info "GPU (Win32_VideoController):"
  Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, DriverDate, AdapterRAM, Status |
    Format-Table -AutoSize | Out-String | Write-Host
}
