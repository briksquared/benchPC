#Requires -Version 5.1
<#
.SYNOPSIS
  Network adapters, IP config, DNS, connectivity, firewall profile.
#>

function Invoke-NetworkDiagnostics {
  Write-Section "Network"

  Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress |
    Format-Table -AutoSize | Out-String | Write-Host

  Get-NetIPConfiguration | ForEach-Object {
    [pscustomobject]@{
      Interface = $_.InterfaceAlias
      IPv4      = ($_.IPv4Address.IPAddress -join ', ')
      Gateway   = ($_.IPv4DefaultGateway.NextHop -join ', ')
      DNS       = ($_.DNSServer.ServerAddresses -join ', ')
    }
  } | Format-Table -AutoSize | Out-String | Write-Host

  Write-Info "Connectivity checks:"
  foreach ($target in @('1.1.1.1', '8.8.8.8', 'google.com')) {
    try {
      $r = Test-Connection -ComputerName $target -Count 2 -Quiet -ErrorAction Stop
      if ($r) { Write-Ok "Reachable: $target" } else { Write-Warn "Unreachable: $target" }
    } catch {
      Write-Warn "Ping failed: $target — $($_.Exception.Message)"
    }
  }

  try {
    Resolve-DnsName www.microsoft.com -Type A -ErrorAction Stop | Select-Object -First 3 Name, Type, IPAddress |
      Format-Table -AutoSize | Out-String | Write-Host
    Write-Ok "DNS resolution OK"
  } catch {
    Write-Fail "DNS resolution failed: $($_.Exception.Message)"
  }

  Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction |
    Format-Table -AutoSize | Out-String | Write-Host

  Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Group-Object LocalPort | Sort-Object Count -Descending | Select-Object -First 15 Name, Count |
    Format-Table -AutoSize | Out-String | Write-Host
}
