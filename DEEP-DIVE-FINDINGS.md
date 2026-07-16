# Deep dive findings + repair status (benchPC)
Generated: 2026-07-16

## Critical findings

### 1. External Toshiba (Disk 1 / F:) — BAD BLOCKS
- System event **disk Id=7**: `Harddisk1\DR1 has a bad block` (many today ~11:27–11:28 AM)
- disk Id=153: IO retry on Disk 1
- Storage reliability: ReadErrorsTotal=19, PowerOnHours~24111
- **Action:** Back up anything important off F: immediately. Replace the drive when practical. Do not use as sole copy of data.

### 2. LiveKernelEvent / BlueScreen signatures (WER today 11:38 AM)
- BlueScreen **bugcheck 0x50** (PAGE_FAULT_IN_NONPAGED_AREA) in WER history
- Multiple LiveKernelEvent entries (141, 1b8, 1b0, etc.)
- No Minidump/MEMORY.DMP on disk previously — CrashControl now set to Automatic dumps for next incident

### 3. RAM not at rated speed
- Corsair 3200 kits running at **2133 MT/s**
- **Action:** `Open-UEFI-For-DOCP.bat` → Ai Tweaker → D.O.C.P. → 3200 → F10

### 4. YellowStar.exe in Common Startup
- Path was: `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\YellowStar.exe`
- Related to `OneDrive\Desktop\octane crackie\...` (cracked software)
- **Action:** Removed from Startup (2026-07-16).

### 5. Priority backup from F: (done)
- Copied to `C:\benchPC-Backup-From-F\`: Documents (5.1GB), 3DPRINTERFILES, Library, Backup
- Full F: (~1.1TB used) still needs another disk if you want everything safe

### 6. Continue hardening (done)
- TRIM on C:, Wi-Fi power saving max performance, indexing off on F:
- Removed CCleaner Smart Cleaning + Razer Cortex from Run
- Component store CheckHealth clean

### 7. BIOS age
- PRIME Z390-A BIOS **1502** (2020-02-20) — optional update from ASUS if instability continues after DOCP

### 8. Event 41 / unexpected shutdowns
- 22 events in 90 days; Fast Startup now **disabled**
- Cluster timestamps often look like log flush after boot rather than fresh crashes

### 9. Other
- Wi-Fi Netwtw10 6062 "Lso was triggered" (Intel AX200) — usually non-fatal power-save
- Ethernet disconnected (cable/link)
- ESP SYSTEM volume Z: Health=Warning (common); NVMe C: Healthy
- Component store repaired; final CheckHealth clean

## Already completed earlier
- DISM RestoreHealth + SFC (repaired corrupt files) + component cleanup
- Fast Startup off, PCIe ASPM off, USB selective suspend off
- WU/BITS services restored

## Scripts
- `Run-DeepDive.ps1` — full deep report
- `Fix-DeepRepair.ps1` — ScanHealth/SFC/power/dumps
- `Fix-Targeted.ps1` — YellowStar removal + volume scans + chkdsk F:/C:
- `Fix-ContinueHardening.ps1` — TRIM / Wi-Fi / startup hardening
- `Backup-PriorityFromF.ps1` — selective F: -> C:\benchPC-Backup-From-F
- `Open-UEFI-For-DOCP.bat` — reboot into BIOS for RAM profile
