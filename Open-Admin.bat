@echo off
:: benchPC — open elevated PowerShell in this folder
cd /d "%~dp0"
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit','-NoProfile','-ExecutionPolicy','Bypass','-Command','Set-Location ''%~dp0''; Write-Host ''benchPC ready. Run .\Run-FullDiag.ps1 or .\Run-Repair.ps1'' -ForegroundColor Cyan'"
