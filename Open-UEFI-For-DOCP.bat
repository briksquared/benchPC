@echo off
:: Reboot into UEFI for D.O.C.P. - 90 second delay (cancel: shutdown /a)
cd /d "%~dp0"
echo.
echo ============================================================
echo  benchPC: Reboot into BIOS to enable RAM D.O.C.P. (3200)
echo ============================================================
echo.
echo  After reboot:
echo    1. Del/F2 already handled - you land in UEFI
echo    2. F7 Advanced Mode if needed
echo    3. Ai Tweaker -^> Ai Overclock Tuner -^> D.O.C.P.
echo    4. Select 3200 profile
echo    5. F10 Save and Exit
echo.
echo  Rebooting in 90 seconds. Cancel with: shutdown /a
echo.
shutdown.exe /r /fw /t 90 /c "benchPC: enable D.O.C.P 3200 for Corsair RAM, then F10"
echo Scheduled. This window can close.
timeout /t 5
