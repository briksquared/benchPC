# Manual BIOS fixes (cannot be done from Windows)

These remaining items need a reboot into ASUS UEFI on the PRIME Z390-A.

## 1. Enable DOCP / XMP (RAM at full speed)

Diag showed Corsair 3200 MT/s kits running at **2133**.

1. Reboot and mash **Del** (or F2) for BIOS.
2. Press **F7** for Advanced Mode if needed.
3. Open **Ai Tweaker**.
4. Set **Ai Overclock Tuner** to **D.O.C.P.** (or XMP) and pick the 3200 profile.
5. **F10** Save & Exit.

After boot, verify in Task Manager -> Performance -> Memory that speed is ~3200.

## 2. Optional BIOS update

Current BIOS string was **American Megatrends 1502** dated **2020-02-20**.

Only update if you still see Kernel-Power 41 unexpected shutdowns after DOCP:

1. Download the latest PRIME Z390-A BIOS from ASUS for your exact board revision.
2. Use ASUS EZ Flash in BIOS (USB FAT32). Do not interrupt power.

## 3. Unexpected shutdowns (Kernel-Power 41)

Software repair (DISM/SFC) completed. If 41s continue:

- Check PSU / wall power / surge strip
- Reseat GPU power cables
- After enabling DOCP, run Windows Memory Diagnostic once
- Prefer Ethernet if Wi-Fi drops cause hard freezes (Ethernet was disconnected during diag)

## 4. Ethernet disconnected

Physical link was down during diagnostics. Plug a cable into the I219-V port if you want wired networking; no software fault was indicated.
