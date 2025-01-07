<#
.SYNOPSIS
    This script demonstrates the process of obtaining an access token using the OAuth 2.0 authorization code flow.
    It was created whilst working with a SaaS provider who had issues performing the 3-legged OAuth process.
    The code validated that the App and the API permissions were correctly configured on the Azure AD side.

.DESCRIPTION
    The script performs the following steps:
    1. Defines the app registration details, including the client ID, client secret, and redirect URI.
    2. Generates the authorization URL based on the app registration details and specified scopes.
    3. Starts a lightweight HTTP listener to receive the OAuth response.
    4. Opens the browser for the user to authenticate and provide consent.
    5. Waits for the OAuth response from the authorization server.
    6. Exchanges the authorization code for an access token.
    7. Retrieves the access token and ID token from the response and copies them to the clipboard.

.PARAMETER clientId
    The client ID of the registered application.

.PARAMETER clientSecret
    The client secret of the registered application.

.PARAMETER redirectUri
    The redirect URI to which the authorization server will redirect the user after authentication.

.PARAMETER authorizationEndpoint
    The URL of the authorization endpoint of the OAuth server.

.PARAMETER scopes
    The scopes to request during the authorization process.

.OUTPUTS
    None.

.EXAMPLE
    .\validateOAuthScopesTokens.ps1

.NOTES
    This script requires the System.Web and System.Runtime assemblies to be loaded.

.LINK
    [OAuth 2.0 Authorization Code Flow](https://oauth.net/2/grant-types/authorization-code/)
#>

# Define the app registration details
$clientId = "cc4024e3-************"
$clientSecret = "********************"
$redirectUri = "http://localhost:125/"
$tenantID = "***********"

# returns user email address under the property unique_name
$authorizationEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize"

<# returns user email address in the id token under the property email
    $authorizationEndpoint = "https://login.microsoftonline.com/common/oauth2/authorize"
#>

$scopes = "openid", "email", "profile"

# Generate the authorization URL
$authorizationUrl = "$($authorizationEndpoint)?client_id=$clientId&response_type=code&redirect_uri=$redirectUri&scope=$($scopes -join '%20')"

Write-Host "Starting 3-legged auth process to request user consent and get refresh token"

# Include statements for .net Assemblies
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
$strAccessToken = (Invoke-WebRequest -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Method POST -Body $body -ContentType "application/x-www-form-urlencoded" -UseBasicParsing).Content 

$access_token = (ConvertFrom-Json $strAccessToken).access_token
$access_token | clip
$idtoken = (ConvertFrom-Json $strAccessToken).id_token
$idtoken | clip
