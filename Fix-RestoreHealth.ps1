$ErrorActionPreference="Continue"
$log="C:\Users\briks\Desktop\benchPC\reports\dism-restore-again.log"
Start-Transcript $log -Force | Out-Null
Write-Host "RestoreHealth start $(Get-Date -Format o)"
dism /Online /Cleanup-Image /RestoreHealth
Write-Host "RestoreHealth exit=$LASTEXITCODE"
dism /Online /Cleanup-Image /CheckHealth
Write-Host "CheckHealth exit=$LASTEXITCODE"
sfc /scannow
Write-Host "SFC exit=$LASTEXITCODE"
Write-Host "DONE $(Get-Date -Format o)"
Stop-Transcript | Out-Null
