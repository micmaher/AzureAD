# Define the app registration details
$clientId = "cc4024e3-************"
$clientSecret = "********************"
$redirectUri = "http://localhost:125/"

# Define the authorization endpoint and scopes
$authorizationEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize"
$scopes = "openid", "email", "profile"

# Generate the authorization URL
$authorizationUrl = "$($authorizationEndpoint)?client_id=$clientId&response_type=code&redirect_uri=$redirectUri&scope=$($scopes -join '%20')"



    Add-Type -AssemblyName System.Web
    Add-Type -AssemblyName System.Runtime
    $LandingPage = "LandingPage.html"
    $webPageResponse = Get-Content ./3LO/$LandingPage
    <# Encode and calc the length for use later #>
    $webPageResponseEncoded =  [System.Text.Encoding]::UTF8.GetBytes($webPageResponse)
    $webPageResponseLength = $webPageResponseEncoded.Length

    <# Start up our lightweight HTTP Listener for the OAuth Response #>
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($redirecturi)
    $listener.Start()

    <# Build our OAuth Query string #>
    $uri = New-Object System.UriBuilder -ArgumentList $authorizationEndpoint
    $query = [System.Web.HttpUtility]::ParseQueryString($uri.Query)

    $query["client_id"] = $clientid
    $query["redirect_uri"] = $redirecturi
    $query["response_type"] = "code"
    $query["scope"] =  $scopes
    $query["prompt"] = "consent"


    $uri.Query = $query.ToString()

    Write-Verbose $uri.Query

    <# Open up the browser for the User to OAuth in #>
    Start-Process $uri.Uri
    

    <# Waits for a response from the OAuth website#>
    $context = $listener.getContext()

    <# You can fetch any other necessary response values here #>
    $code = $context.Request.QueryString["code"]

    <# Write out our landing page for the user #>
    $response = $context.response
    $response.ContentLength64 = $webPageResponseLength
    $response.ContentType = "text/html; charset=UTF-8"
    $response.OutputStream.Write($webPageResponseEncoded, 0, $webPageResponseLength)
    $response.OutputStream.Close()

    <# Close the HTTP Listener #>
    $listener.Stop()

    # Exchange the OAuth code for an access token
    $body = "code=$code&redirect_uri=$redirecturi&client_id=$clientid&client_secret=$clientsecret&scope=$($query["scope"])&grant_type=authorization_code"
    $strAccessToken = (Invoke-WebRequest -Uri "https://login.microsoftonline.com/cf3dc8a2-b7cc-4452-848f-cb570a56cfbf/oauth2/v2.0/token" -Method POST -Body $body -ContentType "application/x-www-form-urlencoded" -UseBasicParsing).Content 


    $access_token = (ConvertFrom-Json $strAccessToken).access_token
  
