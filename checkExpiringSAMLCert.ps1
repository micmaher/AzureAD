<#
.SYNOPSIS
    Gets Expiring SAML Signing Certs in Azure

.DESCRIPTION
    Requires AzureAD module
    Checks Service Principal 
    Maximum lifetime for cert is 3 years
    
.EXAMPLE
    (Get-AzureADServicePrincipal -Filter "displayName eq '$app_name'").keyCredentials | Where-Object {$_.Usage -eq "Sign"} |select EndDate


.NOTES
    NAME:      getExpiringSAMLCert


#>     
[cmdletbinding()]
Param()

#region Variables

$Kscript = "getExpiringSAMLCert"
$Kdate = (Get-Date).ToString('yyyy-MM-dd_H-mm')
$klogRoot = "E:\Scripts\Logs"
$ownerArchive = "E:\scripts\Azure\ownerSvcPrincArchive.xml"
$previousAppPermissions = Import-Clixml -Path $ownerArchive

# Get-AzureADApplication -SearchString "Corp IT Azure Application Inventory" # Get AppId

$appID = '3224d552-9635-4d65-941d-1ec3f0ed4a56' # Corp IT Azure Application Inventory
$cert = Get-ChildItem -Path Cert:\LocalMachine\My | Where {$_.subject -like "CN=reports.tamg.io"}

$appID2 = 'ba368149-0a79-4262-b138-ba420c6a8d4f' # Corp IT Azure Automated Cert Renewal
$cert2 = Get-ChildItem -Path Cert:\LocalMachine\My | Where {$_.subject -like "CN=cloud.tamg.io*"} 

$tenantID = 'cf3dc8a2-b7cc-4452-848f-cb570a56cfbf'

$kSchema = 'dbo'
$kSQLSERVER = 'NDH-SQL-03.us.tripadvisor.local'
$kLastUpdateTable = 'dbo.genericLastUpdated'
$kDBName = 'Reports'
$kSchema = 'dbo'
$kTable = $kScript

$kDBName2 = 'Metrics'
$labelRoot1 = 'directory.aad.expiringsamlcert' 
$labelRoot2 = 'directory.aad.noownersamlapp' 
$labelRoot3 = 'directory.aad.saml.certs'
 
$jiraserver = 'https://jira.tripadvisor.com'
$jiraaccount = 'pstasks-svc' 


$AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null # Turn SSL validation back on
#endregion


#region Logging
    if(!(Test-Path -Path "$klogRoot\$Kscript" )){
        New-Item -ItemType directory -Path "$klogRoot\$Kscript"
    }
    Start-Transcript -Path "$klogRoot\$Kscript\$Kdate-$kScript.log"
#endregion


#region Functions & Modules

If (Get-Command -ea SilentlyContinue Write-SqlTableData){ 
     Write-Verbose "(SQL cmdlets are already loaded.)"
     } 
Else{
     Write-Verbose "Loading SQL Module"
     Import-Module sqlServer}

If (Get-Command -ea SilentlyContinue Connect-AzureAD){ 
     Write-Verbose "(AzureAD cmdlets are already loaded.)"
     } 
Else{
     Write-Verbose "Loading AzureAD Module"
     Import-Module AzureAD}


If (Get-Command -ea SilentlyContinue New-JiraTicket){ 
    Write-Verbose "Jira cmdlets are already loaded.)"
    } 
Else{
    Write-Verbose "Loading NewJiraTicket Module"
    Import-Module NewJiraTicket
}

If (Get-Command Set-PAServer -ea SilentlyContinue ){
    Write-Verbose "(POSH-ACME cmdlets are already loaded.)"
    } Else{
    Write-Verbose "Loading POSH-ACME Module"
    Import-Module Posh-ACME -Force
}
If (Get-Command New-AzDnsRecordSet -ea SilentlyContinue ){
    Write-Verbose "(Az.DNS cmdlets are already loaded.)"
    } Else {
    Write-Verbose "Loading Az.DNS Module"
    Import-Module Az.DNS
}

If (Get-Command Send-SlackNotification -ea SilentlyContinue ){
    Write-Verbose "(Send-SlackNotification function is already loaded.)"
    } Else {
    Write-Verbose "Send-SlackNotification function"
    . "$klogRoot\..\Utility\SendSlackNotification\SendSlackNotification.ps1"
}


If (Get-Command Set-JiraConfigServer -ea SilentlyContinue ){
    Write-Verbose "JiraPS module is already loaded.)"
    } Else {
    Write-Verbose "Import JiraPS"
    Import-Module JiraPS
} 

#endregion


#region Pull Data From Azure

$connect = Connect-AzureAD -ApplicationId $AppId -CertificateThumbprint $cert.Thumbprint -TenantId $tenantID

Write-Verbose "Connected to $($connect.TenantDomain) as Corp IT Azure Application Inventory using $($connect.Account.type) login"

try {Get-AzureADTenantDetail | Out-Null} 
catch { Connect-AzureAD | Out-Null } 
 
Write-Verbose "Gathering information about Azure AD integrated applications..."
Try { 
    $ServicePrincipals = Get-AzureADServicePrincipal -All:$true | Where-Object {$_.Tags -eq "WindowsAzureActiveDirectoryIntegratedApp"} 
    Write-Verbose "Found $($ServicePrincipals.count) Service Principals"
    } 
Catch { 
    Write-Warning "You must connect to Azure AD first!" -ErrorAction Stop 
    } 


# First get all SAML certs
$appPermissions = @();$i=0; 
foreach ($ServicePrincipal in $ServicePrincipals) { 

    Write-Verbose "Working on Service Principal $($i + 1) of $($ServicePrincipals.count)  - $($ServicePrincipal.displayname)"


    Write-Verbose "Checking SAML Signing Cert Expiry"

    #$ServicePrincipal| Where-Object {$_.keyCredentials.Usage -eq "Sign"} | Select -ExpandProperty KeyCredentials |select EndDate
    
    If ($ServicePrincipal.KeyCredentials.Usage -eq "Sign"){ 
    
        Write-Verbose "Found SAML app $($ServicePrincipal.DisplayName)"

        $objPermissions = New-Object PSObject    
        $owner = Get-AzureADServicePrincipalOwner -ObjectId $ServicePrincipal.ObjectId

        #$i++;Add-Member -InputObject $objPermissions -MemberType NoteProperty -Name "Number" -Value $i 
        Add-Member -InputObject $objPermissions -MemberType NoteProperty -Name "Application Name" -Value $ServicePrincipal.DisplayName -Verbose
        Add-Member -InputObject $objPermissions -MemberType NoteProperty -Name "Expiry" -Value ($ServicePrincipal.KeyCredentials| Where-Object {$_.Usage -eq "Sign"}| select EndDate).EndDate
        Add-Member -InputObject $objPermissions -MemberType NoteProperty -Name "Homepage" -Value $ServicePrincipal.Homepage -Verbose
        Add-Member -InputObject $objPermissions -MemberType NoteProperty -Name "Publisher" -Value $ServicePrincipal.PublisherName -Verbose
        Add-Member -InputObject $objPermissions -MemberType NoteProperty -Name "Owner" -Value (($owner | Select-Object -ExpandProperty displayName) -Join ",")
        Add-Member -InputObject $objPermissions -MemberType NoteProperty -Name "UPN" -Value (($owner | Select-Object -ExpandProperty userPrincipalName) -Join ",")

        $appPermissions += $objPermissions 
    }
} 
$appPermissions | Export-Clixml -Depth 3 -Path $ownerArchive -Force
Disconnect-AzureAD

#endregion

#region Interogate Data
# SAML apps with no Owners
$noowners =@()
$noowners = $appPermissions | where {-not($_.Owner)} | select -ExpandProperty 'application name'

$withpreviousowner = Foreach ($n in  $noowners ){
    $previousAppPermissions | Where {$_.'Application Name' -eq $n} | Select-Object 'Application Name', Owner, UPN
}

# Get only expiring SAML certs
$expiringSAMLCerts = @()
$onlyLatestExpiringSAMLCerts = @()
$expiringSAMLCerts = $appPermissions | Where {$_.expiry -lt (Get-Date).AddDays(30)}

$expiringSAMLCerts = $appPermissions | 
    Select 'Application Name', Homepage, Publisher, Owner, UPN, @{l="Expiry";e={$_.expiry | Select -first 1}} | 
    Where {$_.expiry -lt (Get-Date).AddDays(30)}



$urgentExpiringSAMLCerts = $appPermissions | 
    Select 'Application Name', Homepage, Publisher, Owner, UPN, @{l="Expiry";e={$_.expiry | Select -first 1}} | 
    Where {$_.expiry -lt (Get-Date).AddHours(48)}

# Create a test ticket
#$expiringSAMLCerts = $appPermissions | Where {$_.'Application Name' -like "*Secret*"}
#$urgentExpiringSAMLCerts = $appPermissions | Where {$_.'Application Name' -like "*Secret*"}


$allSAMLCerts = $appPermissions | Where {$null -ne $_.expiry}

#endregion


#region Jira


If ($noowners){


Set-JiraConfigServer $jiraserver
$jirasession = New-JiraSession -Credential (Get-SavedCredential $jiraaccount -Context 'Windows') 

If ($noowners.Count -gt 1){$plural = 's'}Else{$plural = $null}

$summary1 = "Found Azure Enterprise Application$plural (Service Principal$plural) without $(If ($plural){"an"}) assigned owner$plural"

Get-JiraIssue -Query "Project=CT AND status = Ready AND summary ~ `"$summary1`" AND created >= -31d" -OutVariable existingOwnerCT

If (-not($existingOwnerCT)){


Write-Warning "Found expiring Azure Enterprise Application$plural (Service Principal$plural) without assigned owner$plural"


$jiraformatted = "{html}<pre><br>$($withpreviousowner  | Out-String)<br><br></pre>{html}"

$Description = @"

This is an automated ticket generated by $kScript.ps1 running on $env:COMPUTERNAME

Found Azure Enterprise Application$plural (Service Principal$plural) without assigned owner$plural

The previous owner$plural is shown below.


$jiraformatted


The owner needs to be updated in Azure AD to ensure we have a contact when the signing certificate expires. 

Update the application by going to Azure Active Directory, Enterpise Applications and searching for the application.

Choose Owner and add the user.

This alert will not regenerate until this ticket is closed.

The latest data can be found here https://reports.tamg.io/Content/Azure/SAMLAppNoOwner.cshtml

"@


New-JiraIssue -Project "CT" -IssueType "Ticket" -Summary $summary1 -Description $Description -Reporter $jiraaccount -Labels 'Unplanned_Support'


}

}


If ($expiringSAMLCerts){

    If (-not($jirasession)){
    Set-JiraConfigServer $jiraserver
    $jirasession = New-JiraSession -Credential (Get-SavedCredential $jiraaccount -Context 'Windows') 
     }

    If ($expiringSAMLCerts.Count -gt 1){$plural = 's'}Else{$plural = $null}
    Write-Verbose "Azure AD SAML Signing Cert$plural is expiring so raising a CT" 

# Separate tickets for each expiring cert
Foreach ($e in $expiringSAMLCerts){

    $summary = "The SAML Signing Certificate used in Azure for $($e.'Application Name') is expiring" 
    $owners = $e.Owner -split ","
    If (($owners).count -gt 1){$ownerplural = "s"}

$Description = @"

This is an automated ticket generated by $kScript.ps1 running on $env:COMPUTERNAME



The SAML signing certificate for *$($e.'Application Name')* will expire on *$($e.expiry)* (US date format).

If the certificate or application is no longer in use please remove it or this alert will page the on-call engineer as the expiry comes closer.

The certificate needs to be updated in the Azure AD portal and also in the application (Service Provider).

The application owner$ownerplural ($($e.Owner)) $(If ($ownerplural){"are"}Else{"is"}) added as a watcher to this ticket.

The owner$ownerplural $(If ($ownerplural){"have"}Else{"has"}) access rights to update the SAML Signing cert themselves if they wish.


############################################################

Steps to replace the SAML Signing Cert in Azure


1. Go to https://portal.azure.com 

2. Choose Azure Active Directory, Enterprise Applications and search for *$($e.'Application Name')*.

3. Next choose Sign Sign On

4. Choose Edit under Section 3 'SAML Signing Certificate'

5. Create a New Certificate

6. Save the changes

7. Download the new certificate

8. Add the new signing certificate to your application

############################################################


This alert will not regenerate until this ticket is closed.

"@

    Get-JiraIssue -Query "Project=CT AND status = Ready AND summary ~ `"$summary`" AND created >= -31d" -OutVariable existingCT
    
    If (-not($existingCT)){
        New-JiraIssue -Project "CT" -IssueType "Ticket" -Summary $summary -Description $Description -Reporter $jiraaccount -Labels 'Unplanned_Support' -OutVariable ticket
        $OwnerUPN = $e.UPN -split ","
        Foreach ($u in $OwnerUPN){
            Add-JiraIssueWatcher -Watcher $((Get-Aduser -Filter "UserPrincipalName -eq '$u'").samaccountname) -Issue $ticket.key
        }
    }
    Else{
        Write-Verbose "Ticket $(($existingCT).key) already open so will not create a new one"
    }
}

}

If ($jirasession){Remove-JiraSession -Session $jirasession}

#endregion


#region Send Data

# Grafana



$time = (Get-Date(Get-Date).ToUniversalTime() -Format "yyyy-MM-dd HH:mm:ss")

Invoke-Sqlcmd -Query "DELETE FROM $kDBName2.$kSchema.$($kScript);" -ServerInstance $kSQLSERVER        

If ($expiringSAMLCerts){   
    Invoke-Sqlcmd -Query "INSERT INTO $kDBName2.$kSchema.$($kScript) VALUES ('$($labelRoot1)', '$($expiringSAMLCerts.count)', '$time', 'Expiring SAML Cert');" -ServerInstance $kSQLSERVER        
}
Else{
    Invoke-Sqlcmd -Query "INSERT INTO $kDBName2.$kSchema.$($kScript) VALUES ('$($labelRoot1)', '0', '$time', 'Expiring SAML Cert');" -ServerInstance $kSQLSERVER       
}

If ($noowners){   
    Invoke-Sqlcmd -Query "INSERT INTO $kDBName2.$kSchema.$($kScript) VALUES ('$($labelRoot2)', '$($noowners.count)', '$time', 'SAML App No Owner');" -ServerInstance $kSQLSERVER        
}
Else{
    Invoke-Sqlcmd -Query "INSERT INTO $kDBName2.$kSchema.$($kScript) VALUES ('$($labelRoot2)', '0', '$time', 'SAML App No Owner');" -ServerInstance $kSQLSERVER       
}

$grpSAMLCerts = $allSAMLCerts | foreach {
    [pscustomobject]@{
        metricvalue = [int]1;
        time        = Get-Date([datetime]($_.Expiry | Select -first 1)).ToUniversalTime() -Format "yyyy-MM-dd HH:mm:ss"
        metricpath  = $_.'Application Name'
        label       = $labelRoot3
        }
    } 

# Metrics DB
Invoke-Sqlcmd -Query "DELETE FROM $kDBName2.$kSchema.AllSAMLCertExpiry WHERE label = '$labelRoot3'" -ServerInstance $kSQLSERVER 
#Write-SqlTableData -ServerInstance $kSQLServer -DatabaseName $kDBName2 -SchemaName $kSchema -TableName "AllSAMLCertExpiry" -InputData $grpSAMLCerts -Verbose -Force
Foreach ($g in $grpSAMLCerts){
    Invoke-Sqlcmd -Query "INSERT INTO AllSAMLCertExpiry VALUES ('$($g.label)', '$($g.metricvalue)', '$($g.time)', '$($g.metricpath)');" -Database $kDBName2 -ServerInstance $kSQLSERVER
}

# Reports DB
Invoke-Sqlcmd -Query "DELETE FROM $kDBName.$kSchema.AllSAMLCertExpiry" -ServerInstance $kSQLSERVER 


If ($allSAMLCerts){
Write-SqlTableData -ServerInstance $kSQLServer -DatabaseName $kDBName -SchemaName $kSchema -TableName "AllSAMLCertExpiry" -InputData $allSAMLCerts -Verbose
}

# SQL

# Last Updated Table
$exists = Invoke-Sqlcmd -Query "SELECT * from $kLastUpdateTable WHERE recordname = '$($kScript)';" -Database $kDBName -ServerInstance $kSQLSERVER
If ($exists){Invoke-Sqlcmd -Query "UPDATE $kLastUpdateTable SET lastupdated = (GetDate()), recordname = '$($kScript)' WHERE recordname = '$($kScript)';" -Database $kDBName -ServerInstance $kSQLSERVER}
Else {Invoke-Sqlcmd -Query "INSERT INTO $kLastUpdateTable (lastupdated, recordname) VALUES ((GetDate()), '$($kScript)');" -Database $kDBName -ServerInstance $kSQLSERVER}


# Expiring Certs Table
Write-Verbose "Flushing $kDBName.$kSchema.$kTable"
Invoke-Sqlcmd -Query "delete from $kDBName.$kSchema.$kTable" -ServerInstance $kSQLSERVER


If ($expiringSAMLCerts){

    Foreach ($e in $expiringSAMLCerts){
        $samaccountname = $(Get-Aduser -Filter "UserPrincipalName -eq '$($e.UPN -split "," | Select -first 1)'").samaccountname
        $e | Add-Member -MemberType NoteProperty -Name "samAccountname" -Value $samaccountname
    }

    $expiringSAMLCertsSQL =  $expiringSAMLCerts | select 'Application Name', Homepage, Publisher, Owner, UPN, @{l="Expiry";e={[string]$_.expiry}}
    Write-SqlTableData -ServerInstance $kSQLServer -DatabaseName $kDBName -SchemaName $kSchema -TableName $Kscript -InputData $expiringSAMLCertsSQL -Verbose -Force

}

# No App Owners
$noownerTable = "$kTable" + "noowner"
Write-Verbose "Flushing $kDBName.$kSchema.$noownerTable"
Invoke-Sqlcmd -Query "delete from $kDBName.$kSchema.$noownerTable" -ServerInstance $kSQLSERVER

If ($noowners){

    Foreach ($n in $noowners){
        Invoke-Sqlcmd -Query "INSERT INTO $noownerTable (AzureSAMLApp) VALUES ('$n');" -Database $kDBName -ServerInstance $kSQLSERVER
        }
}
#endregion

If ($urgentExpiringSAMLCerts){
<# 
    PagerDuty de-duplicates incidents based on the incident_key parameter; this identifies the incident to which a trigger event should be applied.
    If there are no open (unresolved) incidents with this key, a new incident will be created.
    If there is already an open incident with a matching key, this event will be appended to that incident's alert log as an additional Trigger log entry.
#>

    Write-Verbose "Sending Page"
    $pagerDutyObject = New-Object PSObject -Property @{
        urgentSAMLExpiry = $urgentExpiringSAMLCerts
    }
    try
    {
        $resultText = Send-PagerDutyEvent -Trigger -ServiceKey 'c1346b0141a04c8eb47e1fb4095dea7c' -Description ("An Azure SAML Signing Certificate for $($urgentExpiringSAMLCerts.'Application Name') is expiring shortly") -Details "$($pagerDutyObject.urgentSAMLExpiry)" -IncidentKey $kScript
        $resultText = $resultText.Status
    
        $actionResult = 0
    }
    
    catch
    {
        $resultText = $_.Exception.Message
        $actionResult = 1
    }
    
    finally
    {
        $actionResult, $resultText
    }
}

Disconnect-AzureAD
Stop-Transcript
