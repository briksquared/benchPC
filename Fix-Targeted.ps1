#Requires -Version 5.1
# Targeted fixes: remove YellowStar startup, scan/repair volumes, chkdsk external
$ErrorActionPreference = 'Continue'
$here = 'C:\Users\briks\Desktop\benchPC'
$log = Join-Path $here 'reports\targeted-fixes.log'
Start-Transcript $log -Force | Out-Null
function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
try {
  if (-not (Test-IsAdmin)) { throw 'Need admin' }
  Write-Host '=== Remove YellowStar from startup ==='
  $startupDirs = @(
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    'C:\Users\Public\Desktop'
  )
  foreach ($d in $startupDirs) {
    if (-not (Test-Path $d)) { continue }
    Get-ChildItem $d -Force -EA SilentlyContinue | Where-Object { $_.Name -match 'YellowStar|Yellow.?Star' } | ForEach-Object {
      Write-Host "Removing $($_.FullName)"
      Remove-Item -LiteralPath $_.FullName -Force -EA Continue
    }
  }
  # WMI listed Command YellowStar.exe User Public -> often Startup folder shortcut without full path
  Get-ChildItem "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp" -Force -EA SilentlyContinue | ForEach-Object {
    if ($_.Name -match 'Yellow' -or (Get-Content $_.FullName -EA SilentlyContinue) -match 'YellowStar') {
      Write-Host "Removing startup item $($_.FullName)"
      Remove-Item -LiteralPath $_.FullName -Force -EA Continue
    }
  }
  # Also scan all user Startup folders
  Get-ChildItem 'C:\Users' -Directory -EA SilentlyContinue | ForEach-Object {
    $su = Join-Path $_.FullName 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
    if (Test-Path $su) {
      Get-ChildItem $su -Force -EA SilentlyContinue | Where-Object { $_.Name -match 'Yellow' } | ForEach-Object {
        Write-Host "Removing $($_.FullName)"
        Remove-Item -LiteralPath $_.FullName -Force -EA Continue
      }
    }
  }

  Write-Host '=== Repair-Volume scan C: F: Z: ==='
  foreach ($letter in @('C','F','Z')) {
    try {
      Write-Host "Scanning ${letter}:"
      Repair-Volume -DriveLetter $letter -Scan -Verbose | Out-String | Write-Host
    } catch {
      Write-Host "Skip ${letter}: $($_.Exception.Message)"
    }
  }

  Write-Host '=== CHKDSK F: /scan (external Toshiba - bad blocks reported) ==='
  # Online scan first
  & chkntfs.exe F:
  & chkdsk.exe F: /scan
  Write-Host "chkdsk F /scan exit=$LASTEXITCODE"

  Write-Host '=== CHKDSK C: /scan ==='
  & chkdsk.exe C: /scan
  Write-Host "chkdsk C /scan exit=$LASTEXITCODE"

  Write-Host '=== Disable write-cache flush warnings note ==='
  Get-PhysicalDisk | Format-Table FriendlyName, HealthStatus, OperationalStatus, BusType -AutoSize | Out-String | Write-Host

  Write-Host "TARGETED DONE $(Get-Date -Format o)"
}
finally { Stop-Transcript | Out-Null }
