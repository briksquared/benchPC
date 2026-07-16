#Requires -Version 5.1
<#
.SYNOPSIS
  Disk health, SMART-ish status via MSFT, volume free space, CHKDSK online scan status.
#>

function Invoke-DiskDiagnostics {
  Write-Section "Disk & volume health"

  Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus, Size, BusType |
    Format-Table -AutoSize | Out-String | Write-Host

  Get-Disk | Select-Object Number, FriendlyName, PartitionStyle, OperationalStatus, HealthStatus, Size |
    Format-Table -AutoSize | Out-String | Write-Host

  Get-Volume | Where-Object { $_.DriveLetter } | Select-Object DriveLetter, FileSystemLabel, FileSystem,
    @{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}},
    @{N='FreeGB';E={[math]::Round($_.SizeRemaining/1GB,1)}},
    @{N='FreePct';E={ if ($_.Size -gt 0) { [math]::Round(100*$_.SizeRemaining/$_.Size,1) } else { 0 } }},
    HealthStatus |
    Format-Table -AutoSize | Out-String | Write-Host

  foreach ($v in (Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' })) {
    $pct = if ($v.Size -gt 0) { 100.0 * $v.SizeRemaining / $v.Size } else { 100 }
    if ($pct -lt 10) {
      Write-Warn "Low free space on $($v.DriveLetter): - $([math]::Round($pct,1))% free"
    } elseif ($v.HealthStatus -and $v.HealthStatus -ne 'Healthy') {
      Write-Warn "Volume $($v.DriveLetter): health = $($v.HealthStatus)"
    } else {
      Write-Ok "Volume $($v.DriveLetter): OK ($([math]::Round($pct,1))% free)"
    }
  }

  Write-Info "Storage reliability counters (where available):"
  try {
    Get-StorageReliabilityCounter -ErrorAction SilentlyContinue |
      Select-Object DeviceId, Temperature, Wear, ReadErrorsTotal, WriteErrorsTotal, PowerOnHours |
      Format-Table -AutoSize | Out-String | Write-Host
  } catch {
    Write-Warn "Storage reliability counters unavailable: $($_.Exception.Message)"
  }
}
