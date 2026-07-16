#Requires -Version 5.1
<#
.SYNOPSIS
  Selective backup from failing external F: to C:\benchPC-Backup-From-F
  Only copies priority folders that fit free space.
#>
$ErrorActionPreference = 'Continue'
$destRoot = 'C:\benchPC-Backup-From-F'
$log = 'C:\Users\briks\Desktop\benchPC\reports\backup-F.log'
New-Item -ItemType Directory -Force -Path $destRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null

$priority = @(
  'Documents',
  'Backup',
  'Library',
  '3DPRINTERFILES',
  'Import'
)

function Get-DirSizeGB([string]$path) {
  if (-not (Test-Path $path)) { return 0 }
  $sum = (Get-ChildItem -LiteralPath $path -Recurse -File -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum
  if (-not $sum) { return 0 }
  return [math]::Round($sum / 1GB, 2)
}

$freeGB = [math]::Round((Get-Volume C).SizeRemaining / 1GB, 1)
"Backup start $(Get-Date -Format o) C_free_GB=$freeGB" | Tee-Object $log

$plan = @()
foreach ($name in $priority) {
  $src = Join-Path 'F:\' $name
  if (-not (Test-Path $src)) { "$name MISSING" | Tee-Object $log -Append; continue }
  $gb = Get-DirSizeGB $src
  $plan += [pscustomobject]@{ Name = $name; Src = $src; GB = $gb }
  "$name size_GB=$gb" | Tee-Object $log -Append
}

$need = ($plan | Measure-Object GB -Sum).Sum
"Total priority GB=$need Free=$freeGB" | Tee-Object $log -Append
if ($need -gt ($freeGB - 30)) {
  "WARN: Not enough free space for all priority folders (keep 30GB headroom). Will copy largest-first until full." | Tee-Object $log -Append
}

$remaining = $freeGB - 30
foreach ($item in ($plan | Sort-Object GB)) {
  if ($item.GB -le 0) { continue }
  if ($item.GB -gt $remaining) {
    "SKIP $($item.Name) GB=$($item.GB) remaining=$remaining" | Tee-Object $log -Append
    continue
  }
  $dest = Join-Path $destRoot $item.Name
  "COPY $($item.Name) -> $dest" | Tee-Object $log -Append
  robocopy $item.Src $dest /E /COPY:DAT /R:1 /W:1 /XJ /NFL /NDL /NP /BYTES | Tee-Object $log -Append
  $remaining = [math]::Round((Get-Volume C).SizeRemaining / 1GB, 1) - 30
  "After copy free_headroom_estimate=$remaining" | Tee-Object $log -Append
}

"Backup DONE $(Get-Date -Format o)" | Tee-Object $log -Append
Write-Host "Log: $log Dest: $destRoot"
