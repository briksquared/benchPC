#Requires -Version 5.1
<#
.SYNOPSIS
  Repair actions: DISM, SFC, network stack, temp cleanup, Windows Update reset helpers.
#>

function Repair-ComponentStore {
  Require-Admin
  Write-Section "DISM RestoreHealth"
  Write-Info "This can take 10-30+ minutes..."
  & dism.exe /Online /Cleanup-Image /RestoreHealth
  if ($LASTEXITCODE -eq 0) { Write-Ok "DISM RestoreHealth completed" } else { Write-Fail "DISM exit code $LASTEXITCODE" }
}

function Repair-SystemFiles {
  Require-Admin
  Write-Section "System File Checker (SFC)"
  Write-Info "This can take 10-30+ minutes..."
  & sfc.exe /scannow
  if ($LASTEXITCODE -eq 0) { Write-Ok "SFC completed" } else { Write-Warn "SFC exit code $LASTEXITCODE (check CBS.log)" }
}

function Repair-NetworkStack {
  Require-Admin
  Write-Section "Network stack reset"
  Write-Warn "Winsock/TCP reset may require a reboot and briefly drop connectivity."
  & netsh.exe winsock reset
  & netsh.exe int ip reset
  & ipconfig.exe /flushdns
  Write-Ok "Network reset commands issued - reboot recommended"
}

function Repair-TempCleanup {
  Write-Section "Temp & cache cleanup (safe)"
  $targets = @(
    $env:TEMP,
    (Join-Path $env:SystemRoot 'Temp'),
    (Join-Path $env:LOCALAPPDATA 'Temp')
  )
  foreach ($t in $targets) {
    if (-not (Test-Path $t)) { continue }
    Write-Info "Cleaning $t"
    Get-ChildItem -Path $t -Force -ErrorAction SilentlyContinue | ForEach-Object {
      try {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
      } catch {
        # locked files are normal
      }
    }
    Write-Ok "Pass complete: $t"
  }

  if (Test-IsAdmin) {
    Write-Info "Empty Recycle Bin"
    try {
      Clear-RecycleBin -Force -ErrorAction Stop
      Write-Ok "Recycle Bin emptied"
    } catch {
      Write-Warn "Recycle Bin: $($_.Exception.Message)"
    }
  }
}

function Repair-WindowsUpdateComponents {
  Require-Admin
  Write-Section "Windows Update component reset"
  Write-Warn "Stops update services, clears SoftwareDistribution download cache, restarts services."

  $services = @('wuauserv', 'bits', 'cryptsvc', 'msiserver')
  foreach ($s in $services) {
    Write-Info "Stopping $s"
    Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
  }

  $sd = Join-Path $env:SystemRoot 'SoftwareDistribution'
  $cat = Join-Path $env:SystemRoot 'System32\catroot2'
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  if (Test-Path $sd) {
    Rename-Item $sd ("SoftwareDistribution.bak-$stamp") -ErrorAction SilentlyContinue
  }
  if (Test-Path $cat) {
    Rename-Item $cat ("catroot2.bak-$stamp") -ErrorAction SilentlyContinue
  }

  foreach ($s in @('cryptsvc', 'bits', 'wuauserv')) {
    Start-Service -Name $s -ErrorAction SilentlyContinue
    Write-Info "Started $s"
  }
  Write-Ok "Windows Update reset done - try checking for updates"
}

function Repair-DiskCheckSchedule {
  Require-Admin
  Write-Section "Schedule CHKDSK on next boot (C:)"
  Write-Warn "Marks C: dirty; CHKDSK runs on next reboot. Confirm carefully."
  & chkntfs.exe /c C:
  Write-Info "To force offline scan on reboot you can run: chkdsk C: /f /r (interactive confirm)."
  Write-Ok "Volume check bit guidance printed - run chkdsk interactively if needed"
}

function Start-MemoryDiagnostic {
  Require-Admin
  Write-Section "Windows Memory Diagnostic"
  Write-Warn "Schedules a memory test and reboots. Save your work first."
  & mdsched.exe
  Write-Info "Follow the on-screen prompt to restart and test."
}
