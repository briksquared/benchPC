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

Reports land in `reports\`.

## Scripts

| Script | Purpose |
|--------|---------|
| `Run-FullDiag.ps1` | Full health snapshot (hardware, disk, memory, network, events, services) |
| `Run-Repair.ps1` | Guided repair: DISM, SFC, network reset helpers, temp cleanup |
| `modules\*.ps1` | Individual diagnostic / repair modules |

## GitHub

`https://github.com/briksquared/benchPC`
