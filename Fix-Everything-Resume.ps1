$ErrorActionPreference = "Continue"
Start-Service bits -ErrorAction SilentlyContinue
Start-Service wuauserv -ErrorAction SilentlyContinue
Set-Service bits -StartupType Manual -ErrorAction SilentlyContinue
Set-Service wuauserv -StartupType Manual -ErrorAction SilentlyContinue
Get-Service bits,wuauserv,DoSvc | Format-Table Name,Status,StartType | Out-String | Set-Content C:\Users\briks\Desktop\benchPC\reports\wu-services.txt

# If DISM hung with no CBS activity, kill and rerun full repair without waiting on old process
$cbs = Get-Item C:\Windows\Logs\CBS\CBS.log
$ageMin = ((Get-Date) - $cbs.LastWriteTime).TotalMinutes
"CBS age minutes: $ageMin" | Add-Content C:\Users\briks\Desktop\benchPC\reports\wu-services.txt
if ($ageMin -gt 10) {
  Get-Process dism,DismHost -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep 3
  "Killed hung DISM, relaunching Fix-Everything" | Add-Content C:\Users\briks\Desktop\benchPC\reports\wu-services.txt
  # Continue remaining steps inline
  & dism.exe /Online /Cleanup-Image /RestoreHealth | Tee-Object -FilePath C:\Users\briks\Desktop\benchPC\reports\dism-out.txt
  "DISM exit $LASTEXITCODE" | Add-Content C:\Users\briks\Desktop\benchPC\reports\wu-services.txt
  & sfc.exe /scannow | Tee-Object -FilePath C:\Users\briks\Desktop\benchPC\reports\sfc-out.txt
  "SFC exit $LASTEXITCODE" | Add-Content C:\Users\briks\Desktop\benchPC\reports\wu-services.txt
  & dism.exe /Online /Cleanup-Image /StartComponentCleanup | Tee-Object -FilePath C:\Users\briks\Desktop\benchPC\reports\cleanup-out.txt
  "Cleanup exit $LASTEXITCODE" | Add-Content C:\Users\briks\Desktop\benchPC\reports\wu-services.txt
  & netsh.exe int ip reset | Out-File C:\Users\briks\Desktop\benchPC\reports\netsh-out.txt
  & ipconfig.exe /flushdns | Out-File C:\Users\briks\Desktop\benchPC\reports\dns-out.txt -Append
  "ALL DONE $(Get-Date -Format o)" | Add-Content C:\Users\briks\Desktop\benchPC\reports\wu-services.txt
}
