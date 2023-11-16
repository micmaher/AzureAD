<#
.SYNOPSIS
    Health Check Password Protection Proxy

.DESCRIPTION
    Health Check on On-Premises Password Protection Agent and Proxy

.NOTES
    NAME:      CheckPasswordProtectionProxy
    AUTHOR:    Michael Maher 
    URI:       https://learn.microsoft.com/en-us/azure/active-directory/authentication/howto-password-ban-bad-on-premises-troubleshoot#health-testing-with-powershell-cmdlets
    
.EXAMPLE

    This is what an error would look like

    Test-AzureADPasswordProtectionProxyHealth -VerifyProxyRegistration

    DiagnosticName          Result AdditionalInfo
    --------------          ------ --------------
    VerifyProxyRegistration Failed No proxy certificates were found - please run the Register-AzureADPasswordProtectionProxy cmdlet to register the proxy.
 
#>     
[cmdletbinding()]
Param()

#region Variables
$kScript = 'checkPasswordProtection'
$Kdate = ( get-date ).ToString('yyyy-MM-dd_H-mm')
$klogRoot = 'E:\Scripts\Logs'
$Timestamp = [Math]::Floor([decimal](Get-Date([datetime](Get-Date)).ToUniversalTime()-uformat "%s"))
$kSchema = 'dbo'
$kSQLSERVER = 'SQL-03.acme.com'
$kLastUpdateTable = 'dbo.genericLastUpdated'
$kDBName = 'Reports'
$kTable = $kScript

#endregion


#region Logging
    if(!(Test-Path -Path "$klogRoot\$Kscript" )){
        New-Item -ItemType directory -Path "$klogRoot\$Kscript"
    }
    Start-Transcript -Path "$klogRoot\$Kscript\$Kdate-$kScript.log"
#endregion


# Locate a proxy server to work with
$scp = "serviceConnectionPoint"
$keywords = "{ebefb703-6113-413d-9167-9f8dd4d24468}*"
$proxyServers = Get-ADObject -SearchScope Subtree -Filter { objectClass -eq $scp -and keywords -like $keywords }
$proxyServers | select -Property *
$serverDN = ($proxyServers.DistinguishedName).replace('CN=AzureADPasswordProtectionProxy,','') 


$LatestAzureADPasswordProtectionVersion = "1.2.177.1"

#$pssession = New-PSSession -ComputerName $proxyFQDN -Credential 'us\admin-mmaher'


Foreach ($s in $serverDN){

    $proxyFQDN = (Get-ADComputer $s).DNSHostName

    $proxyTests += Invoke-Command -ComputerName $proxyFQDN -ScriptBlock {

    }
}

Remove-PSSession -Session $pssession


Get-AzureADPasswordProtectionSummaryReport
Get-AzureADPasswordProtectionProxy
Get-AzureADPasswordProtectionDCAgent 
Get-AzureADPasswordProtectionProxyConfiguration
Test-AzureADPasswordProtectionDCAgentHealth -TestAll
When Azure rejects the password, it will show the event ID 10025 and event ID 30009.

Event 10025, DCAgent

Get-AzureADPasswordProtectionProxy

$LatestAzureADPasswordProtectionVersion = "1.2.177.1"
Get-AzureADPasswordProtectionDCAgent | Where-Object {$_.SoftwareVersion -lt $LatestAzureADPasswordProtectionVersion}

Stop-Transcript
