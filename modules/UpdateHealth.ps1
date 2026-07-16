#Requires -Version 5.1
<#
.SYNOPSIS
  Windows Update / component store quick checks (read-only).
#>

function Invoke-UpdateDiagnostics {
  Write-Section "Windows Update & component health (read-only)"

  Write-Info "Recent Windows Update history (COM):"
  try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $historyCount = $searcher.GetTotalHistoryCount()
    if ($historyCount -gt 0) {
      $searcher.QueryHistory(0, [Math]::Min(12, $historyCount)) |
        Select-Object Date, Title, @{N='Result';E={
          switch ($_.ResultCode) { 0 {'NotStarted'} 1 {'InProgress'} 2 {'Succeeded'} 3 {'SucceededWithErrors'} 4 {'Failed'} 5 {'Aborted'} default {$_.ResultCode} }
        }} |
        Format-Table -AutoSize | Out-String | Write-Host
    } else {
      Write-Info "No update history entries."
    }
  } catch {
    Write-Warn "Update history unavailable: $($_.Exception.Message)"
  }

  Write-Info "CBS / DISM related events (last 7 days):"
  try {
    Get-WinEvent -FilterHashtable @{LogName='Setup'; StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue |
      Where-Object { $_.LevelDisplayName -in @('Error','Warning') } |
      Select-Object -First 10 TimeCreated, Id, LevelDisplayName, Message |
      Format-List | Out-String | Write-Host
  } catch {
    Write-Info "No Setup log warnings/errors."
  }

  if (Test-IsAdmin) {
    Write-Info "Quick DISM CheckHealth (admin):"
    & dism.exe /Online /Cleanup-Image /CheckHealth
  } else {
    Write-Warn "Skip DISM CheckHealth (not admin). Re-run elevated for component store check."
  }
}
