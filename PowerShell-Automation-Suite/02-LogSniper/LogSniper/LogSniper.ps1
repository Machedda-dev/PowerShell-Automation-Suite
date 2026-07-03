<#
.SYNOPSIS
    Scans log files for specific patterns with optional date filters and HTML export.

.DESCRIPTION
    This script searches a log file for matching patterns (keywords, IPs, regex).
    NEW: Filter by StartDate/EndDate. NEW: Export as HTML for professional dashboards.

.PARAMETER LogPath
    The full path to the log file to scan.

.PARAMETER Pattern
    The keyword, IP, or regex pattern to search for.

.PARAMETER ExportPath
    The folder where results will be saved. Default: C:\LogSniper_Reports

.PARAMETER ExportType
    "CSV", "TXT", or "HTML". Default is "CSV".

.PARAMETER StartDate
    (NEW) Filter lines ON or AFTER this datetime. Format: "yyyy-MM-dd HH:mm:ss"

.PARAMETER EndDate
    (NEW) Filter lines ON or BEFORE this datetime. Format: "yyyy-MM-dd HH:mm:ss"

.EXAMPLE
    .\LogSniper.ps1 -LogPath .\sample_log.log -Pattern "10.10.50.12"

.EXAMPLE
    .\LogSniper.ps1 -LogPath .\sample_log.log -Pattern "POST" -StartDate "2026-07-01 10:00" -EndDate "2026-07-01 11:00"

.EXAMPLE
    .\LogSniper.ps1 -LogPath .\sample_log.log -Pattern " 403" -ExportType HTML

.NOTES
    Author: Vincent Ododa
    Date: 2026-07-01
    Version: 2.0 (Added Date Filters & HTML Export)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$LogPath,
    
    [Parameter(Mandatory=$true)]
    [string]$Pattern,
    
    [string]$ExportPath = "C:\LogSniper_Reports",
    
    [ValidateSet("CSV", "TXT", "HTML")]
    [string]$ExportType = "CSV",
    
    # NEW PARAMETERS (Optional)
    [string]$StartDate,
    [string]$EndDate
)

# --- VALIDATION ---
if (-not (Test-Path $LogPath)) {
    Write-Host "[ERROR] Log file not found: $LogPath" -ForegroundColor Red
    exit 1
}

# Create export directory if it doesn't exist
if (-not (Test-Path $ExportPath)) {
    New-Item -Path $ExportPath -ItemType Directory -Force | Out-Null
    Write-Host "[INFO] Created directory: $ExportPath" -ForegroundColor Green
}

# --- DATE FILTER PARSING (Seamless Logic) ---
$FilterDateStart = $null
$FilterDateEnd = $null

if ($StartDate) {
    try {
        $FilterDateStart = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd HH:mm:ss', $null)
        Write-Host "[INFO] Filtering lines ON or AFTER: $FilterDateStart" -ForegroundColor Yellow
    } catch {
        Write-Host "[ERROR] Invalid StartDate format. Use 'yyyy-MM-dd HH:mm:ss'" -ForegroundColor Red
        exit 1
    }
}

if ($EndDate) {
    try {
        $FilterDateEnd = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd HH:mm:ss', $null)
        Write-Host "[INFO] Filtering lines ON or BEFORE: $FilterDateEnd" -ForegroundColor Yellow
    } catch {
        Write-Host "[ERROR] Invalid EndDate format. Use 'yyyy-MM-dd HH:mm:ss'" -ForegroundColor Red
        exit 1
    }
}

# --- PERFORM THE SEARCH ---
Write-Host "[INFO] Scanning $LogPath for pattern: '$Pattern'" -ForegroundColor Yellow

# Grab all raw matches
$AllMatches = Select-String -Path $LogPath -Pattern $Pattern -AllMatches

# Apply Date Filter if provided (NEW LOGIC)
if ($FilterDateStart -or $FilterDateEnd) {
    $Results = $AllMatches | Where-Object {
        # Extract the timestamp from the beginning of the line (first 19 characters)
        $LineDate = $null
        if ($_.Line.Length -ge 19) {
            try {
                $LineDate = [datetime]::ParseExact($_.Line.Substring(0, 19), 'yyyy-MM-dd HH:mm:ss', $null)
            } catch {
                # If parsing fails, keep the line (edge case)
                return $true
            }
        }
        
        $PassStart = $true
        $PassEnd = $true
        
        if ($FilterDateStart) {
            $PassStart = $LineDate -ge $FilterDateStart
        }
        if ($FilterDateEnd) {
            $PassEnd = $LineDate -le $FilterDateEnd
        }
        
        return ($PassStart -and $PassEnd)
    }
} else {
    # No date filters provided: seamless fallback to original behavior
    $Results = $AllMatches
}

# --- COUNT AND REPORT ---
$MatchCount = $Results.Count

if ($MatchCount -eq 0) {
    Write-Host "[INFO] No matches found for the given criteria." -ForegroundColor Yellow
    exit 0
}

Write-Host "[SUCCESS] Found $MatchCount matching lines." -ForegroundColor Cyan

# --- GENERATE TIMESTAMP ---
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BaseFileName = "LogSniper_$Timestamp"

# --- EXPORT ENGINE (UPGRADED TO HTML) ---
if ($ExportType -eq "HTML") {
    $ExportFile = Join-Path -Path $ExportPath -ChildPath "$BaseFileName.html"
    
    # Build a nice HTML report
    $Results | Select-Object LineNumber, Line | ConvertTo-Html -Title "Log Sniper Report" -Head @"
<style>
    body { font-family: Arial, sans-serif; margin: 20px; background: #f4f4f4; }
    h1 { color: #333; }
    table { border-collapse: collapse; width: 100%; background: white; }
    th { background: #007acc; color: white; padding: 10px; text-align: left; }
    td { padding: 8px; border-bottom: 1px solid #ddd; font-family: monospace; font-size: 12px; }
    tr:hover { background: #e6f2ff; }
    .summary { background: #e8e8e8; padding: 10px; border-radius: 5px; margin-bottom: 20px; }
</style>
"@ -Body "<div class='summary'><strong>Report Generated:</strong> $(Get-Date) <br><strong>Pattern Searched:</strong> '$Pattern' <br><strong>Total Matches:</strong> $MatchCount</div>" | Out-File -FilePath $ExportFile -Encoding UTF8
    
    Write-Host "[SUCCESS] HTML report saved to: $ExportFile" -ForegroundColor Green
    
} elseif ($ExportType -eq "CSV") {
    $ExportFile = Join-Path -Path $ExportPath -ChildPath "$BaseFileName.csv"
    $Results | Select-Object LineNumber, Line | Export-Csv -Path $ExportFile -NoTypeInformation
    Write-Host "[SUCCESS] CSV report saved to: $ExportFile" -ForegroundColor Green
    
} else {
    # TXT Export
    $ExportFile = Join-Path -Path $ExportPath -ChildPath "$BaseFileName.txt"
    $Results | ForEach-Object { $_.Line } | Out-File -FilePath $ExportFile -Encoding UTF8
    Write-Host "[SUCCESS] TXT report saved to: $ExportFile" -ForegroundColor Green
}

# --- PREVIEW (First 5 lines) ---
Write-Host "[INFO] Preview of matches:" -ForegroundColor Yellow
$Results | Select-Object -First 5 | ForEach-Object {
    Write-Host "  Line $($_.LineNumber): $($_.Line)" -ForegroundColor Gray
}