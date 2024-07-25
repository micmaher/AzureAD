
Function Send-GraphApiEmail {
    param (
        [string]$AccessToken,
        [string]$Recipient,
        [string]$Subject,
        [string]$Body,
        [string]$From = 'notificationcenter@company.com'
    )

    $graphApiEndpoint = "https://graph.microsoft.com/v1.0/users/$($From)/sendMail"
    $headers = @{
        Authorization = "Bearer $accessToken"
        "Content-Type" = "application/json"
    }

    $emailData = @{
        message = @{
            subject = $Subject
            body = @{
                contentType = "HTML"
                content = $Body
            }
            toRecipients = @(
                @{
                    emailAddress = @{
                        address = $Recipient
                    }
                }
            )
            from = @{
                emailAddress = @{
                    address = $From
                }
            }
        }
    }

    $emailJson = $emailData | ConvertTo-Json -Depth 100
    Invoke-RestMethod -Uri $graphApiEndpoint -Method Post -Headers $headers -Body $emailJson -ContentType "application/json"
}

Function Get-AccessToken {
    param (
        [String]$ClientId,
        [SecureString]$ClientSecret,
        [String]$TenantId = '12234455030303030'
    )

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClientSecret)
    $clientSecretClear = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $clientId
        client_secret = $clientSecretClear
        scope         = "https://graph.microsoft.com/.default"
    }

    $response = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $body
    return $response.access_token
}

$clientId = '126262762862868268628'
$clientSecret = Get-SavedCredential -UserName notificationcenter -Context 'GraphApi' 
$recipient = 'mmaher@company.com'
$from = 'notificationcenter@company.com'

try {
    # Get the access token
    $accessToken = Get-AccessToken -ClientId $clientId -ClientSecret $clientSecret.Password

    # Compose the email subject and body
    $subject = "Test Email from PowerShell"
    $body = "This is a test email sent from PowerShell using Microsoft Graph API."
    $sender = "Notification Center <$from>"

    # Send the email
    Send-GraphApiEmail -AccessToken $AccessToken -Recipient $recipient -Subject $subject -Body $body -From $from

    Write-Host "Email sent successfully!"
}
catch {
    Write-Host "Failed to send email: $($_.Exception.Message)"
}
