#Requires -Version 5.1
<#
.SYNOPSIS
  Deep-dive diagnostics for benchPC - writes a structured report.
#>
[CmdletBinding()]
param([string]$OutFile)

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'modules\Common.ps1')

if (-not $OutFile) {
  $OutFile = Join-Path (Get-BenchReportDir) ("deep-dive-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
}

function Out([string]$s) { Add-Content -Path $OutFile -Value $s; Write-Host $s }
function Sec([string]$t) { Out ''; Out ('=' * 72); Out "  $t"; Out ('=' * 72) }

Set-Content -Path $OutFile -Value "benchPC DEEP DIVE $(Get-Date -Format o)"
Out "Admin: $(Test-IsAdmin)"
Out "Computer: $env:COMPUTERNAME / $env:USERNAME"

Sec '1) Hardware / firmware'
$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$board = Get-CimInstance Win32_BaseBoard
$cpu = Get-CimInstance Win32_Processor
Out ("Board: {0} {1}" -f $board.Manufacturer, $board.Product)
Out ("BIOS:  {0} {1} ({2})" -f $bios.Manufacturer, $bios.SMBIOSBIOSVersion, $bios.ReleaseDate)
Out ("CPU:   {0} load={1}%" -f $cpu.Name, $cpu.LoadPercentage)
Out ("Model: {0} {1}" -f $cs.Manufacturer, $cs.Model)

Sec '2) Memory modules / XMP status'
Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
  Out ("{0} | {1} | {2} GB | SPD/Cfg {3}/{4} MT/s | {5}" -f $_.BankLabel, $_.PartNumber, [math]::Round($_.Capacity/1GB,0), $_.Speed, $_.ConfiguredClockSpeed, $_.Manufacturer)
}
$cfg = @(Get-CimInstance Win32_PhysicalMemory | ForEach-Object { $_.ConfiguredClockSpeed }) | Measure-Object -Average
if ($cfg.Average -lt 3000) { Out 'FINDING: RAM below 3000 MT/s -> D.O.C.P/XMP not applied in BIOS' }

Sec '3) Storage health'
Get-PhysicalDisk | ForEach-Object {
  Out ("Disk: {0} | {1} | Health={2} | Op={3} | Size={4:N0} GB | Bus={5}" -f $_.FriendlyName, $_.MediaType, $_.HealthStatus, $_.OperationalStatus, ($_.Size/1GB), $_.BusType)
}
Get-Volume | Where-Object DriveLetter | ForEach-Object {
  $pct = if ($_.Size) { [math]::Round(100*$_.SizeRemaining/$_.Size,1) } else { 0 }
  Out ("Vol {0}: {1} {2}% free Health={3}" -f $_.DriveLetter, $_.FileSystemLabel, $pct, $_.HealthStatus)
}
try {
  Get-PhysicalDisk | ForEach-Object {
    $c = $_ | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
    if ($c) {
      Out ("Reliability {0}: Temp={1} Wear={2} ReadErr={3} WriteErr={4} PowerOnHours={5}" -f $_.FriendlyName, $c.Temperature, $c.Wear, $c.ReadErrorsTotal, $c.WriteErrorsTotal, $c.PowerOnHours)
    }
  }
} catch { Out "Reliability counters: $($_.Exception.Message)" }

Sec '4) Kernel-Power 41 / unexpected shutdowns (90 days)'
try {
  $ev = Get-WinEvent -FilterHashtable @{LogName='System'; Id=41,1001,6008; StartTime=(Get-Date).AddDays(-90)} -ErrorAction SilentlyContinue
  Out ("Count last 90d: $($ev.Count)")
  $ev | Select-Object -First 20 | ForEach-Object {
    Out ("[{0}] Id={1} {2}" -f $_.TimeCreated, $_.Id, ($_.Message -replace '\s+',' ').Substring(0, [Math]::Min(180, ($_.Message -replace '\s+',' ').Length)))
  }
} catch { Out $_.Exception.Message }

Sec '5) Bugcheck / WHEA / disk / nvlddmkm / netwtw (30 days)'
foreach ($prov in @(
  @{Name='WHEA-Logger'; Id=$null},
  @{Name='Microsoft-Windows-WHEA-Logger'; Id=$null},
  @{Name='disk'; Id=$null},
  @{Name='ntfs'; Id=$null},
  @{Name='nvlddmkm'; Id=$null},
  @{Name='Netwtw10'; Id=$null},
  @{Name='e1dexpress'; Id=$null},
  @{Name='volmgr'; Id=$null}
)) {
  try {
    $f = @{LogName='System'; StartTime=(Get-Date).AddDays(-30); ProviderName=$prov.Name}
    $items = Get-WinEvent -FilterHashtable $f -ErrorAction SilentlyContinue | Where-Object { $_.Level -le 3 }
    Out ("Provider $($prov.Name): $($items.Count) warn/error (30d)")
    $items | Group-Object Id | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
      Out ("  Id=$($_.Name) count=$($_.Count)")
    }
  } catch { }
}

Sec '6) Application crashes (7 days)'
try {
  Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Application Error','Windows Error Reporting'; StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue |
    Select-Object -First 15 TimeCreated, Id, ProviderName, @{N='Msg';E={($_.Message -replace '\s+',' ').Substring(0,[Math]::Min(160,($_.Message -replace '\s+',' ').Length))}} |
    ForEach-Object { Out ("[{0}] {1}" -f $_.TimeCreated, $_.Msg) }
} catch { Out $_.Exception.Message }

Sec '7) SFC / CBS repair evidence'
$cbs = 'C:\Windows\Logs\CBS\CBS.log'
if (Test-Path $cbs) {
  Out "CBS.log size=$((Get-Item $cbs).Length) LastWrite=$((Get-Item $cbs).LastWriteTime)"
  Select-String -Path $cbs -Pattern '\[SR\].*Repairing|\[SR\].*Ignoring|Corrupt file|Repairing file|Verify complete|Found corrupt' -ErrorAction SilentlyContinue |
    Select-Object -Last 40 | ForEach-Object { Out $_.Line.Trim() }
} else { Out 'No CBS.log' }

Sec '8) Fast Startup / power'
$hb = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -ErrorAction SilentlyContinue).HiberbootEnabled
Out "HiberbootEnabled=$hb (0=Fast Startup off)"
Out (powercfg /getactivescheme)
& powercfg /query SCHEME_CURRENT SUB_PCIEXPRESS ASPM 2>$null | Select-String 'Current AC|Current DC|Power Setting|0x' | ForEach-Object { Out $_.Line.Trim() }

Sec '9) Drivers / problem devices'
Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } | ForEach-Object {
  Out ("PROBLEM: {0} code={1}" -f $_.Name, $_.ConfigManagerErrorCode)
}
Out 'GPU:'
Get-CimInstance Win32_VideoController | ForEach-Object { Out ("  {0} Driver={1} Date={2} Status={3}" -f $_.Name, $_.DriverVersion, $_.DriverDate, $_.Status) }
Out 'Network adapters:'
Get-NetAdapter | ForEach-Object { Out ("  {0} | {1} | {2} | {3}" -f $_.Name, $_.Status, $_.LinkSpeed, $_.InterfaceDescription) }

Sec '10) Services automatic but stopped'
Get-Service | Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' } |
  ForEach-Object { Out ("  STOPPED AUTO: {0} ({1})" -f $_.Name, $_.DisplayName) }

Sec '11) Minidumps / MEMORY.DMP'
$md = Join-Path $env:SystemRoot 'Minidump'
if (Test-Path $md) {
  Get-ChildItem $md -Filter *.dmp -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 10 |
    ForEach-Object { Out ("  {0} {1:N1}MB {2}" -f $_.Name, ($_.Length/1MB), $_.LastWriteTime) }
} else { Out 'No Minidump folder' }
$mem = Join-Path $env:SystemRoot 'MEMORY.DMP'
if (Test-Path $mem) { $f=Get-Item $mem; Out ("MEMORY.DMP {0:N1}MB {1}" -f ($f.Length/1MB), $f.LastWriteTime) } else { Out 'No MEMORY.DMP' }

Sec '12) Startup load (possible instability contributors)'
Get-CimInstance Win32_StartupCommand | ForEach-Object { Out ("  {0} | {1}" -f $_.Name, $_.Command) }

Sec '13) Findings summary'
Out '- Review sections 2 (RAM/DOCP), 4 (Event 41), 5 (WHEA/disk/GPU), 7 (SFC repairs)'
Out '- Windows software repair already applied earlier; remaining hardware/firmware items need BIOS'
Out "Report: $OutFile"
Write-Host "Deep dive saved: $OutFile" -ForegroundColor Green
