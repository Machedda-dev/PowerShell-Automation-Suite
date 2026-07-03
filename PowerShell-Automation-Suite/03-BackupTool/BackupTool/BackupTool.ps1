<#
.SYNOPSIS
    Automates folder backup with compression, archiving, and retention policy.

.DESCRIPTION
    This script compresses a source folder into a timestamped ZIP archive,
    moves it to a backup destination, and deletes archives older than a
    specified retention period. All actions are logged.

.PARAMETER SourcePath
    The folder to backup (e.g., C:\Projects\TestData).

.PARAMETER BackupDestination
    The folder where ZIP archives will be stored (e.g., C:\Backups).

.PARAMETER RetentionDays
    Number of days to keep backups. Backups older than this are deleted. Default: 30.

.PARAMETER LogPath
    Folder where logs will be saved. Default: C:\BackupLogs.

.EXAMPLE
    .\BackupTool.ps1 -SourcePath "C:\Projects\TestData" -BackupDestination "C:\Backups"

.EXAMPLE
    .\BackupTool.ps1 -SourcePath "C:\Projects\TestData" -BackupDestination "D:\Archives" -RetentionDays 60

.NOTES
    Author: Vincent Ododa
    Date: 2026-07-01
    Version: 1.0
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,
    
    [Parameter(Mandatory=$true)]
    [string]$BackupDestination,
    
    [int]$RetentionDays = 30,
    
    [string]$LogPath = "C:\BackupLogs"
)

# --- SETUP LOGGING ---
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path -Path $LogPath -ChildPath "Backup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    Write-Host $LogEntry -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $LogEntry
}

Write-Log "========== BACKUP SCRIPT STARTED ==========" "Cyan"
Write-Log "Source Path: $SourcePath" "Yellow"
Write-Log "Backup Destination: $BackupDestination" "Yellow"
Write-Log "Retention Days: $RetentionDays" "Yellow"

# --- VALIDATE SOURCE ---
if (-not (Test-Path $SourcePath)) {
    Write-Log "[ERROR] Source folder not found: $SourcePath" "Red"
    exit 1
}

# --- CREATE BACKUP DESTINATION IF MISSING ---
if (-not (Test-Path $BackupDestination)) {
    New-Item -Path $BackupDestination -ItemType Directory -Force | Out-Null
    Write-Log "[INFO] Created backup destination: $BackupDestination" "Green"
}

# --- GENERATE TIMESTAMPED ARCHIVE NAME ---
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$FolderName = Split-Path $SourcePath -Leaf
$ArchiveName = "${FolderName}_Backup_$Timestamp.zip"
$ArchivePath = Join-Path -Path $BackupDestination -ChildPath $ArchiveName

# --- COMPRESS THE SOURCE FOLDER ---
Write-Log "[INFO] Compressing $SourcePath to $ArchivePath" "Yellow"
try {
    Compress-Archive -Path $SourcePath -DestinationPath $ArchivePath -CompressionLevel Optimal -ErrorAction Stop
    Write-Log "[SUCCESS] Archive created: $ArchivePath" "Green"
    $ArchiveSize = [math]::Round((Get-Item $ArchivePath).Length / 1MB, 2)
    Write-Log "[INFO] Archive size: $ArchiveSize MB" "Cyan"
} catch {
    Write-Log "[ERROR] Compression failed: $_" "Red"
    exit 1
}

# --- DELETE BACKUPS OLDER THAN RETENTION PERIOD ---
Write-Log "[INFO] Checking for backups older than $RetentionDays days..." "Yellow"
$CutoffDate = (Get-Date).AddDays(-$RetentionDays)
$OldBackups = Get-ChildItem -Path $BackupDestination -Filter "*.zip" | Where-Object { $_.LastWriteTime -lt $CutoffDate }

if ($OldBackups.Count -eq 0) {
    Write-Log "[INFO] No old backups to delete." "Cyan"
} else {
    foreach ($OldBackup in $OldBackups) {
        try {
            Remove-Item -Path $OldBackup.FullName -Force -ErrorAction Stop
            Write-Log "[SUCCESS] Deleted old backup: $($OldBackup.Name)" "Green"
        } catch {
            Write-Log "[ERROR] Failed to delete $($OldBackup.Name): $_" "Red"
        }
    }
    Write-Log "[INFO] Deleted $($OldBackups.Count) old backup(s)." "Cyan"
}

# --- SUMMARY ---
$TotalBackups = (Get-ChildItem -Path $BackupDestination -Filter "*.zip").Count
$TotalSizeMB = [math]::Round((Get-ChildItem -Path $BackupDestination -Filter "*.zip" | Measure-Object -Property Length -Sum).Sum / 1MB, 2)

Write-Log "========== BACKUP SCRIPT COMPLETED ==========" "Cyan"
Write-Log "[SUMMARY] Total backups in destination: $TotalBackups" "Yellow"
Write-Log "[SUMMARY] Total size of all backups: $TotalSizeMB MB" "Yellow"
Write-Log "[SUMMARY] Log saved to: $LogFile" "Yellow"