#Requires -Version 5.1
<#
.SYNOPSIS
  Shared helpers for benchPC diagnostics and repair.
#>

$script:BenchRoot = Split-Path -Parent $PSScriptRoot
if (-not $script:BenchRoot) { $script:BenchRoot = $PSScriptRoot }

function Get-BenchReportDir {
  $dir = Join-Path $script:BenchRoot 'reports'
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  return $dir
}

function New-BenchReportPath {
  param([string]$Prefix = 'diag')
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  return Join-Path (Get-BenchReportDir) ("{0}-{1}.txt" -f $Prefix, $stamp)
}

function Write-Section {
  param([string]$Title)
  $line = '=' * 72
  Write-Host ""
  Write-Host $line -ForegroundColor Cyan
  Write-Host "  $Title" -ForegroundColor Cyan
  Write-Host $line -ForegroundColor Cyan
}

function Write-Ok { param([string]$Message) Write-Host "[OK]  $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "[!!]  $Message" -ForegroundColor Yellow }
function Write-Fail { param([string]$Message) Write-Host "[ERR] $Message" -ForegroundColor Red }
function Write-Info { param([string]$Message) Write-Host "[..]  $Message" -ForegroundColor Gray }

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($id)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Require-Admin {
  if (-not (Test-IsAdmin)) {
    Write-Fail "Administrator privileges required. Right-click PowerShell -> Run as administrator."
    throw "Not elevated"
  }
}

function Invoke-Logged {
  param(
    [scriptblock]$ScriptBlock,
    [string]$Label
  )
  Write-Info $Label
  try {
    & $ScriptBlock
    Write-Ok $Label
  } catch {
    Write-Fail "$Label - $($_.Exception.Message)"
  }
}

function Start-TranscriptSafe {
  param([string]$Path)
  try {
    Start-Transcript -Path $Path -Force | Out-Null
    return $true
  } catch {
    Write-Warn "Could not start transcript: $($_.Exception.Message)"
    return $false
  }
}

function Stop-TranscriptSafe {
  try { Stop-Transcript | Out-Null } catch { }
}
