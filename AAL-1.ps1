# AAL-1.ps1

$OutputCsv = ".\AzureGovTenantUsers.csv"

# Install once if needed:
# Install-Module Microsoft.Graph -Scope CurrentUser

Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Identity.DirectoryManagement

$Scopes = @(
    "User.Read.All",
    "Directory.Read.All",
    "AuditLog.Read.All"
)

Connect-MgGraph -Environment USGov -Scopes $Scopes
Select-MgProfile -Name "v1.0" -ErrorAction SilentlyContinue

$UserProperties = @(
    "id",
    "accountEnabled",
    "assignedLicenses",
    "userPrincipalName",
    "companyName",
    "displayName",
    "mail",
    "businessPhones",
    "mobilePhone",
    "city",
    "createdDateTime",
    "signInActivity"
)

$users = Get-MgUser -All -Property $UserProperties

$results = foreach ($user in $users) {
    $managerName = $null

    try {
        $manager = Get-MgUserManager -UserId $user.Id -ErrorAction Stop
        $managerName = $manager.AdditionalProperties.displayName

        if ([string]::IsNullOrWhiteSpace($managerName)) {
            $managerName = $manager.AdditionalProperties.userPrincipalName
        }
    }
    catch {
        $managerName = $null
    }

    $phone = if ($user.BusinessPhones -and $user.BusinessPhones.Count -gt 0) {
        $user.BusinessPhones[0]
    }
    elseif ($user.MobilePhone) {
        $user.MobilePhone
    }
    else {
        $null
    }

    $lastLogin = $null
    if ($user.SignInActivity) {
        if ($user.SignInActivity.LastSuccessfulSignInDateTime) {
            $lastLogin = $user.SignInActivity.LastSuccessfulSignInDateTime
        }
        elseif ($user.SignInActivity.LastSignInDateTime) {
            $lastLogin = $user.SignInActivity.LastSignInDateTime
        }
    }

    [PSCustomObject]@{
        "Account Enabled"    = [bool]$user.AccountEnabled
        "Account Licensed"   = ($user.AssignedLicenses.Count -gt 0)
        "User Principal ID"  = $user.UserPrincipalName
        "Company"            = $user.CompanyName
        "Manager"            = $managerName
        "Display Name"       = $user.DisplayName
        "Mail"               = $user.Mail
        "Phone"              = $phone
        "City"               = $user.City
        "Created Date"       = $user.CreatedDateTime
        "Last Login Date"    = $lastLogin
    }
}

$results |
    Sort-Object "User Principal ID" |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "Export complete: $OutputCsv"
Disconnect-MgGraph
