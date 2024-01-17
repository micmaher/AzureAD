Function Invoke-PIMActivation {
    <#
        .SYNOPSIS
            Auto activate PIM
    
        .DESCRIPTION
            PIM up to a group
    
        .PARAMETER AzureUsername
            User to activate in UPN format
                
        .EXAMPLE
            Invoke-PIMActivation -AzureUsername azadm-mmaher@contoso.com
			
  #>
    
    [CmdletBinding()]
    param (
	[Parameter(ValueFromPipeline = $true )]
	[string] $AzureUsername
    )

	$tenantID = '************************'
	$resourceId = "****************" # The resource id of your PIM group
	$reason = "PIM Elevation"
	$activationLength = 8 # in hours

	Import-Module Microsoft.Graph.Authentication -Verbose:$false
	Import-Module  Microsoft.Graph.Identity.DirectoryManagement -Verbose:$false

	Write-Verbose "Connecting to Entra using the Microsoft.Graph.Authentication module..."
	$null = Connect-MgGraph -TenantId $tenantID

	# Exit gracefully if the user cancels the auth dialog box
	try {$null = Get-MgOrganization } catch{ Write-Host "You're not connected to Entra so the script will exit";break}

	$aadobjectId = (Get-MgUser -Filter "userPrincipalName eq '$azureUsername'").Id

	Write-Verbose "Checking if PIM activation for $resourceID is already active"
	
	# Check to see if the requested role is already active, and notify the user when it will expire, if it is.
	$filter = "`$filter=groupId eq '$resourceId' and principalId eq '$aadobjectId'"
	$uri = "https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/assignmentSchedules?$filter"

	$pimSchedule = Invoke-MgGraphRequest -Uri $uri -Method GET

	If ($pimSchedule.value.scheduleInfo.expiration.endDateTime){
		Write-Verbose "PIM activation value is not null $($pimSchedule.value)"
		Write-Host -ForegroundColor Green "This role was previously activated on $($pimSchedule.value.scheduleInfo.startDateTime) (UTC), it expires at $($pimSchedule.value.scheduleInfo.expiration.endDateTime) (UTC)"
	} 
	Else {
		Write-Host "Please wait for elevated privilege activation ..."

		$htbody = @{ 

			accessId      =      "member"
			action        =      "selfActivate"
			groupId       =      $resourceId
			justification =      $reason
			principalId   =      $aadobjectId
			scheduleInfo  =  @{
								recurrence    =  $null
								expiration    = @{
												   duration    =  $null
												   endDateTime =  $(Get-Date ((Get-Date).AddHours($activationLength)) -Format "o")
												   type        =  "afterDateTime"
											    }
								startDateTime = $(Get-Date -Format "o")
							}
		}
		
		$jsonBody = $htbody | ConvertTo-Json
		$activationUri = "https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/assignmentScheduleRequests"
		$pimActivation = Invoke-MgGraphRequest -Uri $activationUri -Method POST -Body $jsonBody

        Get-PimStatus -aadObjectID $aadobjectId
		
	}
}


Function Get-PimStatus{
    [CmdletBinding()]
    param (
	[Parameter(ValueFromPipeline = $true )]
	[string] $aadObjectID
    )

    [int] $sleepPeriodMs = 500
    [bool] $needNewline = $false
    $dtStart = [DateTime]::UtcNow
    $pimSchedule = $null # The value return in case of timeout.


	$resourceId = "***************" # The PIM group resID
	$filter = "`$filter=groupId eq '$resourceId' and principalId eq '$aadObjectId'"
	$uri = "https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/assignmentSchedules?$filter"


    do {
    
          # Recheck to see if the requested role is active
       $pimSchedule = Invoke-MgGraphRequest -Uri $uri -Method GET
    
          If ($pimSchedule.value.assignmenttype -ne 'activated'){
              Write-Host "Waiting for activatation to complete in Entra ..."
    
          }
          Write-host '.' -NoNewline; $needNewline = $true
          Start-Sleep -Milliseconds $sleepPeriodMs
        }
    while ($timeout -eq -1 -or ([DateTime]::UtcNow - $dtStart).TotalSeconds -lt $Timeout)

    if ($needNewline) { Write-Host }
    
    return "Status is $($pimSchedule.value.assignmenttype)"
}
