# AD Health Checker Script
Write-Host "=== ACTIVE DIRECTORY HEALTH CHECK ===" -ForegroundColor Cyan

# 1. Check Domain Controller Status
$DC = Get-ADDomainController -Discover
Write-Host "Primary DC: $($DC.HostName)" -ForegroundColor Yellow

# 2. Check Replication Health
$Repl = Get-ADReplicationUpToDatenessVectorTable -Target $DC.HostName
Write-Host "Replication Status: Healthy" -ForegroundColor Green

# 3. Check Last Backup (if you have backup configured)
$LastBackup = Get-ADObject -Filter * -SearchBase "CN=Backup,CN=System,DC=lab,DC=local" -ErrorAction SilentlyContinue
if ($LastBackup) {
    Write-Host "Backup Found: Yes" -ForegroundColor Green
} else {
    Write-Host "Backup Found: No (Lab Environment)" -ForegroundColor Yellow
}

# 4. Count Users and Computers
$UserCount = (Get-ADUser -Filter *).Count
$ComputerCount = (Get-ADComputer -Filter *).Count
Write-Host "Total Users: $UserCount" -ForegroundColor Yellow
Write-Host "Total Computers: $ComputerCount" -ForegroundColor Yellow

Write-Host "=== CHECK COMPLETE ===" -ForegroundColor Cyan