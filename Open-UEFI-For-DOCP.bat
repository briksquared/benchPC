@echo off
:: Reboot this PC straight into ASUS UEFI so you can enable D.O.C.P (XMP).
:: Save work first. Delay is 30 seconds (cancel with: shutdown /a)
cd /d "%~dp0"
echo.
echo ========================================
echo  benchPC - reboot into BIOS for D.O.C.P
echo ========================================
echo.
echo After reboot:
echo   1. Press F7 for Advanced Mode if needed
echo   2. Ai Tweaker -^> Ai Overclock Tuner -^> D.O.C.P.
echo   3. Pick the 3200 profile
echo   4. F10 Save and Exit
echo.
echo Rebooting to UEFI in 30 seconds...
echo Run "shutdown /a" in Admin CMD to cancel.
echo.
shutdown.exe /r /fw /t 30 /c "benchPC: enable D.O.C.P (XMP) for 3200 RAM, then F10 save"
pause
