#Requires -Version 5.1
<#
.SYNOPSIS
  Critical/error event log summary, reliability, BSOD MiniDump presence.
#>

function Invoke-EventDiagnostics {
  Write-Section "Event log & reliability"

  $since = (Get-Date).AddDays(-7)
  foreach ($log in @('System', 'Application')) {
    Write-Info "Top $log errors/warnings since $($since.ToString('u'))"
    try {
      Get-WinEvent -FilterHashtable @{LogName=$log; Level=1,2,3; StartTime=$since} -ErrorAction SilentlyContinue |
        Group-Object ProviderName | Sort-Object Count -Descending | Select-Object -First 12 Count, Name |
        Format-Table -AutoSize | Out-String | Write-Host
    } catch {
      Write-Warn "Could not read $log : $($_.Exception.Message)"
    }
  }

  Write-Info "Recent bugchecks / unexpected shutdowns (System 41, 1001, 6008):"
  try {
    Get-WinEvent -FilterHashtable @{LogName='System'; Id=41,1001,6008; StartTime=(Get-Date).AddDays(-30)} -ErrorAction SilentlyContinue |
      Select-Object -First 15 TimeCreated, Id, ProviderName, Message |
      Format-List | Out-String | Write-Host
  } catch {
    Write-Info "None found or access denied."
  }

  $minidump = Join-Path $env:SystemRoot 'Minidump'
  if (Test-Path $minidump) {
    $dumps = Get-ChildItem $minidump -Filter *.dmp -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($dumps) {
      Write-Warn "Minidumps present ($($dumps.Count)):"
      $dumps | Select-Object -First 10 Name, Length, LastWriteTime | Format-Table -AutoSize | Out-String | Write-Host
    } else {
      Write-Ok "No minidump files"
    }
  } else {
    Write-Ok "No Minidump folder"
  }

  $memdmp = Join-Path $env:SystemRoot 'MEMORY.DMP'
  if (Test-Path $memdmp) {
    $f = Get-Item $memdmp
    Write-Warn ("MEMORY.DMP present: {0:N1} MB, {1}" -f ($f.Length/1MB), $f.LastWriteTime)
  }
}
