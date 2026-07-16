# benchPC

Windows PC diagnostics and repair toolkit for this bench machine.

## Quick start

Run PowerShell **as Administrator**, then:

```powershell
cd $env:USERPROFILE\Desktop\benchPC
Set-ExecutionPolicy -Scope Process Bypass
.\Run-FullDiag.ps1
```

Repair (safe defaults first):

```powershell
.\Run-Repair.ps1
```

Full automated repair (admin / UAC):

```powershell
.\Fix-Everything.ps1
```

Reports land in `reports\`. BIOS/RAM (DOCP) steps that need a reboot are in `MANUAL-BIOS-FIXES.md`.

## Continue fixing

```powershell
# Elevated stability pass (Fast Startup off, power tweaks, CheckHealth)
.\Fix-WindowsStability.ps1

# When ready to set RAM to 3200: double-click Open-UEFI-For-DOCP.bat
```

## Scripts

| Script | Purpose |
|--------|---------|
| `Run-FullDiag.ps1` | Full health snapshot (hardware, disk, memory, network, events, services) |
| `Run-Repair.ps1` | Guided repair: DISM, SFC, network reset helpers, temp cleanup |
| `modules\*.ps1` | Individual diagnostic / repair modules |

## GitHub

`https://github.com/briksquared/benchPC`
