<#
.SYNOPSIS
    Daily Maintenance Suite - Combines system health, log analysis, and backup.

.DESCRIPTION
    This script runs three core tasks:
    1. System Health Check (CPU, RAM, Disk, Services)
    2. Log Analysis (Scans yesterday's logs for errors, warnings, suspicious IPs)
    3. Backup (Compresses and archives a specified folder)
    All results are compiled into a single HTML dashboard.

.PARAMETER LogPath
    The log file to analyze (e.g., C:\Logs\app.log).

.PARAMETER BackupSource
    The folder to backup (e.g., C:\Projects\TestData).

.PARAMETER BackupDestination
    The folder where backups will be stored (e.g., C:\Backups).

.PARAMETER RetentionDays
    Number of days to keep backups. Default: 30.

.PARAMETER OutputPath
    Where to save the HTML report. Default: C:\DailyReports.

.PARAMETER SendEmail
    Switch to enable email sending (requires SMTP config).

.EXAMPLE
    .\DailySuite.ps1 -LogPath "C:\Logs\app.log" -BackupSource "C:\Projects\TestData" -BackupDestination "C:\Backups"

.NOTES
    Author: Vincent Ododa
    Date: 2026-07-01
    Version: 1.0
#>

param(
    [string]$LogPath,
    [Parameter(Mandatory=$true)]
    [string]$BackupSource,
    [Parameter(Mandatory=$true)]
    [string]$BackupDestination,
    [int]$RetentionDays = 30,
    [string]$OutputPath = "C:\DailyReports",
    [switch]$SendEmail
)

# --- SETUP LOGGING ---
$LogFolder = "C:\DailyLogs"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}
$LogFile = Join-Path -Path $LogFolder -ChildPath "DailySuite_$(Get-Date -Format 'yyyy-MM-dd').log"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    Write-Host $LogEntry -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $LogEntry
}

# --- CREATE OUTPUT DIRECTORY ---
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

Write-Log "========== DAILY MAINTENANCE SUITE STARTED ==========" "Cyan"
Write-Log "Backup Source: $BackupSource" "Yellow"
Write-Log "Backup Destination: $BackupDestination" "Yellow"
Write-Log "Retention Days: $RetentionDays" "Yellow"
Write-Log "Log Path: $LogPath" "Yellow"

# ============================================================================
# MODULE 1: SYSTEM HEALTH CHECK
# ============================================================================
Write-Log "[MODULE 1] Running System Health Check..." "Magenta"

$OS = Get-CimInstance -ClassName Win32_OperatingSystem
$CPU = Get-CimInstance -ClassName Win32_Processor
$Memory = Get-CimInstance -ClassName Win32_PhysicalMemory
$TotalRAMGB = [math]::Round(($Memory.Capacity | Measure-Object -Sum).Sum / 1GB, 2)
$FreeRAMGB = [math]::Round($OS.FreePhysicalMemory / 1MB, 2)
$UsedRAMGB = [math]::Round($TotalRAMGB - $FreeRAMGB, 2)
$RAMUsagePercent = [math]::Round(($UsedRAMGB / $TotalRAMGB) * 100, 2)

$Disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
$DiskHTML = foreach ($Disk in $Disks) {
    $TotalGB = [math]::Round($Disk.Size / 1GB, 2)
    $FreeGB = [math]::Round($Disk.FreeSpace / 1GB, 2)
    $UsedGB = [math]::Round($TotalGB - $FreeGB, 2)
    $UsagePercent = [math]::Round(($UsedGB / $TotalGB) * 100, 2)
    "<tr><td>$($Disk.DeviceID)</td><td>$TotalGB GB</td><td>$UsedGB GB</td><td>$FreeGB GB</td><td>$UsagePercent%</td></tr>"
}

$Services = Get-Service | Where-Object { $_.Status -eq "Stopped" -and $_.StartType -eq "Automatic" } | Select-Object -First 10
$ServiceHTML = foreach ($Service in $Services) {
    "<tr><td>$($Service.Name)</td><td>$($Service.DisplayName)</td><td style='color:red;'>Stopped</td></tr>"
}
if (-not $ServiceHTML) {
    $ServiceHTML = "<tr><td colspan='3' style='color:green;'>All automatic services are running.</td></tr>"
}

# ============================================================================
# MODULE 2: LOG ANALYSIS (If LogPath provided)
# ============================================================================
$LogResultsHTML = ""
$SuspiciousIPsHTML = ""
$ErrorCount = 0
$WarnCount = 0
$SuspiciousIPCount = 0

if ($LogPath -and (Test-Path $LogPath)) {
    Write-Log "[MODULE 2] Analyzing log file: $LogPath" "Magenta"
    
    # Count errors and warnings
    $ErrorCount = (Select-String -Path $LogPath -Pattern "ERROR" -AllMatches).Count
    $WarnCount = (Select-String -Path $LogPath -Pattern "WARN" -AllMatches).Count
    
    # Hunt for suspicious IPs (common attack patterns)
    $SuspiciousIPs = Select-String -Path $LogPath -Pattern "\b(192\.168\.[0-9]{1,3}\.[0-9]{1,3}|10\.10\.50\.12)\b" -AllMatches | ForEach-Object { $_.Line }
    $SuspiciousIPCount = $SuspiciousIPs.Count
    
    if ($SuspiciousIPCount -gt 0) {
        $SuspiciousIPsHTML = "<h3>Suspicious IPs Detected ($SuspiciousIPCount)</h3><ul>"
        $SuspiciousIPs | Select-Object -First 10 | ForEach-Object {
            $SuspiciousIPsHTML += "<li style='color:red;'>$_</li>"
        }
        if ($SuspiciousIPCount -gt 10) {
            $SuspiciousIPsHTML += "<li><em>... and $($SuspiciousIPCount - 10) more</em></li>"
        }
        $SuspiciousIPsHTML += "</ul>"
    } else {
        $SuspiciousIPsHTML = "<p style='color:green;'>No suspicious IPs detected.</p>"
    }
    
    # Build log results section
    $LogResultsHTML = @"
<h2>📊 Log Analysis Results</h2>
<table border='1' cellpadding='8'>
<tr><th>Metric</th><th>Count</th></tr>
<tr><td>Total Errors</td><td style='color:red;font-weight:bold;'>$ErrorCount</td></tr>
<tr><td>Total Warnings</td><td style='color:orange;font-weight:bold;'>$WarnCount</td></tr>
<tr><td>Suspicious IPs</td><td style='color:red;font-weight:bold;'>$SuspiciousIPCount</td></tr>
</table>
$SuspiciousIPsHTML
"@
} else {
    $LogResultsHTML = "<p><em>Log analysis skipped (no log path provided or file not found).</em></p>"
}

# ============================================================================
# MODULE 3: BACKUP
# ============================================================================
Write-Log "[MODULE 3] Running backup..." "Magenta"

$BackupSuccess = $false
$BackupSizeMB = 0
$BackupPath = ""

if (Test-Path $BackupSource) {
    # Create backup destination if missing
    if (-not (Test-Path $BackupDestination)) {
        New-Item -Path $BackupDestination -ItemType Directory -Force | Out-Null
    }
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $FolderName = Split-Path $BackupSource -Leaf
    $ArchiveName = "${FolderName}_Backup_$Timestamp.zip"
    $ArchivePath = Join-Path -Path $BackupDestination -ChildPath $ArchiveName
    
    try {
        Compress-Archive -Path $BackupSource -DestinationPath $ArchivePath -CompressionLevel Optimal -ErrorAction Stop
        $BackupSuccess = $true
        $BackupPath = $ArchivePath
        $BackupSizeMB = [math]::Round((Get-Item $ArchivePath).Length / 1MB, 2)
        Write-Log "[SUCCESS] Backup created: $ArchivePath ($BackupSizeMB MB)" "Green"
    } catch {
        Write-Log "[ERROR] Backup failed: $_" "Red"
    }
    
    # Delete old backups
    $CutoffDate = (Get-Date).AddDays(-$RetentionDays)
    $OldBackups = Get-ChildItem -Path $BackupDestination -Filter "*.zip" | Where-Object { $_.LastWriteTime -lt $CutoffDate }
    foreach ($OldBackup in $OldBackups) {
        try {
            Remove-Item -Path $OldBackup.FullName -Force -ErrorAction Stop
            Write-Log "[SUCCESS] Deleted old backup: $($OldBackup.Name)" "Green"
        } catch {
            Write-Log "[ERROR] Failed to delete $($OldBackup.Name): $_" "Red"
        }
    }
} else {
    Write-Log "[ERROR] Backup source not found: $BackupSource" "Red"
}

$TotalBackups = (Get-ChildItem -Path $BackupDestination -Filter "*.zip" -ErrorAction SilentlyContinue).Count
$TotalBackupSizeMB = 0
if ($TotalBackups -gt 0) {
    $TotalBackupSizeMB = [math]::Round((Get-ChildItem -Path $BackupDestination -Filter "*.zip" | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
}

# ============================================================================
# MODULE 4: BUILD HTML DASHBOARD
# ============================================================================
Write-Log "[MODULE 4] Building HTML dashboard..." "Magenta"

$ReportTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$HtmlFile = Join-Path -Path $OutputPath -ChildPath "DailyReport_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').html"

$HtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Daily Maintenance Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 30px;
            background: #f0f2f5;
            color: #333;
        }
        h1 {
            color: #005a9e;
            border-bottom: 3px solid #005a9e;
            padding-bottom: 10px;
        }
        .summary-box {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .section {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 10px 0;
        }
        th {
            background: #005a9e;
            color: white;
            padding: 10px;
            text-align: left;
        }
        td {
            padding: 8px;
            border-bottom: 1px solid #ddd;
        }
        tr:hover {
            background: #e6f2ff;
        }
        .badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 12px;
            font-weight: bold;
            color: white;
        }
        .badge-green { background: #28a745; }
        .badge-yellow { background: #ffc107; color: #333; }
        .badge-red { background: #dc3545; }
        .badge-blue { background: #17a2b8; }
        .footer {
            margin-top: 30px;
            font-size: 12px;
            color: #888;
            text-align: center;
        }
        .highlight-red { color: #dc3545; font-weight: bold; }
        .highlight-green { color: #28a745; font-weight: bold; }
    </style>
</head>
<body>
    <h1>🖥️ Daily Maintenance Report</h1>
    <div class="summary-box">
        <p><strong>Generated:</strong> $ReportTimestamp</p>
        <p><strong>Computer:</strong> $env:COMPUTERNAME</p>
        <p><strong>User:</strong> $env:USERNAME</p>
    </div>
    
    <div class="section">
        <h2>📊 System Health</h2>
        <table border="1" cellpadding="8">
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>OS</td><td>$($OS.Caption) ($($OS.OSArchitecture))</td></tr>
            <tr><td>CPU</td><td>$($CPU.Name) - $($CPU.LoadPercentage)% Load</td></tr>
            <tr><td>RAM Usage</td><td>$RAMUsagePercent% ($UsedRAMGB GB / $TotalRAMGB GB)</td></tr>
        </table>
        <h3>Disk Usage</h3>
        <table border="1" cellpadding="8">
            <tr><th>Drive</th><th>Total</th><th>Used</th><th>Free</th><th>Usage %</th></tr>
            $DiskHTML
        </table>
        <h3>Stopped Automatic Services</h3>
        <table border="1" cellpadding="8">
            <tr><th>Service Name</th><th>Display Name</th><th>Status</th></tr>
            $ServiceHTML
        </table>
    </div>
    
    <div class="section">
        $LogResultsHTML
    </div>
    
    <div class="section">
        <h2>💾 Backup Report</h2>
        <table border="1" cellpadding="8">
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Backup Status</td><td style='color:$(if ($BackupSuccess) { "green" } else { "red" });font-weight:bold;'>$(if ($BackupSuccess) { "✅ SUCCESS" } else { "❌ FAILED" })</td></tr>
            <tr><td>Backup File</td><td>$(if ($BackupSuccess) { $BackupPath } else { "N/A" })</td></tr>
            <tr><td>Backup Size</td><td>$(if ($BackupSuccess) { "$BackupSizeMB MB" } else { "N/A" })</td></tr>
            <tr><td>Total Backups</td><td>$TotalBackups</td></tr>
            <tr><td>Total Backup Size</td><td>$TotalBackupSizeMB MB</td></tr>
            <tr><td>Retention Policy</td><td>Delete backups older than $RetentionDays days</td></tr>
        </table>
    </div>
    
    <div class="footer">
        Generated by Daily Maintenance Suite v1.0 | [Your Name]
    </div>
</body>
</html>
"@

$HtmlContent | Out-File -FilePath $HtmlFile -Encoding UTF8
Write-Log "[SUCCESS] HTML report saved to: $HtmlFile" "Green"

# ============================================================================
# MODULE 5: EMAIL REPORT (UPGRADED - SECURE)
# ============================================================================
if ($SendEmail) {
    Write-Log "[MODULE 5] Preparing to send email report..." "Magenta"
    
    # --- CONFIGURE THESE VARIABLES (Change these to your details) ---
    $SmtpServer = "smtp.gmail.com"          # Or "smtp.office365.com" for Outlook
    $SmtpPort = 587
    $FromAddress = "ododavin95@gmail.com"   
    $ToAddress = "odzodzah@gmail.com"      
    $Subject = "Daily Maintenance Report - $env:COMPUTERNAME"
    
    # --- SECURE CREDENTIAL HANDLING ---
    # Check if a secure credential file exists
    $CredPath = "C:\Projects\DailySuite\email_cred.xml"
    
    if (Test-Path $CredPath) {
        # Load the encrypted credential
        $Credential = Import-CliXml -Path $CredPath
        $Username = $Credential.UserName
        $Password = $Credential.GetNetworkCredential().Password
        Write-Log "[INFO] Loaded saved credentials for: $Username" "Green"
    } else {
        # Prompt for credentials (secure popup)
        Write-Log "[INFO] No saved credentials found. Please enter your email password." "Yellow"
        $Credential = Get-Credential -UserName $FromAddress -Message "Enter your email password"
        $Username = $Credential.UserName
        $Password = $Credential.GetNetworkCredential().Password
        
        # Save the credential securely (encrypted to your Windows profile)
        $Credential | Export-CliXml -Path $CredPath
        Write-Log "[INFO] Credentials saved securely to: $CredPath" "Green"
        Write-Log "[INFO] This file is encrypted and can only be read by your Windows account." "Cyan"
    }
    
    # Send the email
    try {
        $Message = New-Object System.Net.Mail.MailMessage
        $Message.From = $FromAddress
        $Message.To.Add($ToAddress)
        $Message.Subject = $Subject
        $Message.Body = @"
Hello,

Please find the attached daily maintenance report for $env:COMPUTERNAME.

Details:
- Report Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- System: $env:COMPUTERNAME
- User: $env:USERNAME

This is an automated email generated by the Daily Maintenance Suite.

Regards,
Your Automation System
"@
        
        # Attach the HTML report
        $Attachment = New-Object System.Net.Mail.Attachment($HtmlFile)
        $Message.Attachments.Add($Attachment)
        
        # Send via SMTP
        $SmtpClient = New-Object System.Net.Mail.SmtpClient($SmtpServer, $SmtpPort)
        $SmtpClient.EnableSsl = $true
        $SmtpClient.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
        $SmtpClient.Send($Message)
        
        Write-Log "[SUCCESS] Email sent to $ToAddress" "Green"
        
        # Clean up attachment
        $Attachment.Dispose()
        $Message.Dispose()
    } catch {
        Write-Log "[ERROR] Email failed: $_" "Red"
        Write-Log "[HINT] If using Gmail, ensure 'Allow less secure apps' is OFF and use an 'App Password' instead." "Yellow"
    }
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================
Write-Log "========== DAILY MAINTENANCE SUITE COMPLETED ==========" "Cyan"
Write-Log "[SUMMARY] HTML Report: $HtmlFile" "Yellow"
Write-Log "[SUMMARY] Log File: $LogFile" "Yellow"

# Open the HTML report automatically
Start-Process $HtmlFile