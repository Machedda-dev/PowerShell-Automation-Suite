# Bulk User Generator - Creates 20 test users in Corp_Users OU
Write-Host "=== BULK USER CREATION STARTED ===" -ForegroundColor Cyan

# Ensure the AD module is loaded
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$OU = "OU=Corp_Users,DC=lab,DC=local"
$Password = (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force)

for ($i = 1; $i -le 20; $i++) {
    $FirstName = "User"
    $LastName = "Test$i"
    $SamAccount = "tuser$i"
    $UPN = "$SamAccount@lab.local"
    
    try {
        New-ADUser -Name "$FirstName $LastName" `
                   -GivenName $FirstName `
                   -Surname $LastName `
                   -SamAccountName $SamAccount `
                   -UserPrincipalName $UPN `
                   -Path $OU `
                   -AccountPassword $Password `
                   -Enabled $true `
                   -ErrorAction Stop
        Write-Host "Created: $FirstName $LastName ($SamAccount)" -ForegroundColor Green
    } catch {
        # FIXED: Added a space after the variable to avoid the colon conflict
        Write-Host "Failed to create $SamAccount : $_" -ForegroundColor Red
    }
}

Write-Host "=== BULK USER CREATION COMPLETE ===" -ForegroundColor Cyan