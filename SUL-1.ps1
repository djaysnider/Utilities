# SUU-1.ps1

$DaysInactive = 30
$OutputCsv = ".\AzureGovUsers_Inactive_$DaysInactive`Days.csv"
$CutoffDate = (Get-Date).ToUniversalTime().AddDays(-$DaysInactive)

Import-Module Microsoft.Graph.Users

$Scopes = @(
    "User.Read.All",
    "Directory.Read.All",
    "AuditLog.Read.All"
)

Connect-MgGraph -Environment USGov -Scopes $Scopes

$UserProperties = @(
    "id",
    "accountEnabled",
    "userPrincipalName",
    "displayName",
    "mail",
    "companyName",
    "city",
    "createdDateTime",
    "signInActivity"
)

$users = Get-MgUser -All -Property $UserProperties

$inactiveUsers = foreach ($user in $users) {
    $lastLogin = $null

    if ($user.SignInActivity) {
        if ($user.SignInActivity.LastSuccessfulSignInDateTime) {
            $lastLogin = [datetime]$user.SignInActivity.LastSuccessfulSignInDateTime
        }
        elseif ($user.SignInActivity.LastSignInDateTime) {
            $lastLogin = [datetime]$user.SignInActivity.LastSignInDateTime
        }
    }

    if ($null -eq $lastLogin -or $lastLogin.ToUniversalTime() -lt $CutoffDate) {
        [PSCustomObject]@{
            "Account Enabled"    = [bool]$user.AccountEnabled
            "User Principal ID"  = $user.UserPrincipalName
            "Display Name"       = $user.DisplayName
            "Mail"               = $user.Mail
            "Company"            = $user.CompanyName
            "City"               = $user.City
            "Created Date"       = $user.CreatedDateTime
            "Last Login Date"    = $lastLogin
            "Days Since Login"   = if ($lastLogin) {
                [math]::Floor(((Get-Date).ToUniversalTime() - $lastLogin.ToUniversalTime()).TotalDays)
            } else {
                "Never logged in / no sign-in data"
            }
        }
    }
}

$inactiveUsers |
    Sort-Object "Last Login Date", "User Principal ID" |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "Export complete: $OutputCsv"
Write-Host "Cutoff date UTC: $CutoffDate"

Disconnect-MgGraph
