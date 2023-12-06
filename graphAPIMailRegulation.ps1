
$stopwatch =  [system.diagnostics.stopwatch]::StartNew()
$iCount = 0

Foreach ($emailaddress in $emailaddresses){

    # Send Email Message
    $iCount ++
		Write-Verbose "Email Message number $iCount sent to $emailaddress after $([math]::Round($stopwatch.Elapsed.TotalSeconds,2)) seconds"

        # The limit on messages in Office 365 is 30 per minute which means a message rate less than 0.5 per second
        $messagerate = $([math]::Round($icount/([math]::Round($stopwatch.Elapsed.TotalSeconds,0)) * 60))
        If ($messagerate -gt 29){
            Write-Verbose "Message rate of $messagerate messages per minute would exceed the allowed threshold so slowing the script down accordingly"
            Start-Sleep -Seconds 1
        }
        Write-Verbose "Send rate is $messagerate messages per minute"
        
        Try{
            
            Send-GraphApiEmail -AccessToken $AccessToken -Recipient $emailaddress -Subject $subject -Body $fullBody -From $from

            
        }
        
        Catch{
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
        }
}


$stopwatch.Stop()
Write-Verbose "Email delivery took $([math]::Round($stopwatch.Elapsed.TotalSeconds,2)) seconds"
