# User Health Checker - Finds locked/disabled accounts
Write-Host "=== USER HEALTH & SECURITY CHECK ===" -ForegroundColor Cyan

# 1. Check for Locked Out Users using Search-ADAccount
$LockedUsers = Search-ADAccount -LockedOut
if ($LockedUsers) {
    Write-Host "⚠️  LOCKED ACCOUNTS FOUND: $($LockedUsers.Count)" -ForegroundColor Red
    $LockedUsers | ForEach-Object { Write-Host "   - $($_.Name)" -ForegroundColor Yellow }
} else {
    Write-Host "✅ Locked Accounts: None" -ForegroundColor Green
}

# 2. Check for Disabled Users
$DisabledUsers = Get-ADUser -Filter { Enabled -eq $false } -Properties Name
if ($DisabledUsers) {
    Write-Host "⚠️  DISABLED ACCOUNTS FOUND: $($DisabledUsers.Count)" -ForegroundColor Yellow
    $DisabledUsers | ForEach-Object { Write-Host "   - $($_.Name)" -ForegroundColor Gray }
} else {
    Write-Host "✅ Disabled Accounts: None" -ForegroundColor Green
}

# 3. Count Total Active Users
$TotalActive = (Get-ADUser -Filter { Enabled -eq $true }).Count
Write-Host "`nTotal Active Users: $TotalActive" -ForegroundColor Cyan

Write-Host "=== CHECK COMPLETE ===" -ForegroundColor Cyan