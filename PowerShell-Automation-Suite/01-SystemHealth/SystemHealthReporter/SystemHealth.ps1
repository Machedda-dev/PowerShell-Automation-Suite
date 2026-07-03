<#
.SYNOPSIS
    Collects system health information and generates a timestamped report.

.DESCRIPTION
    This script gathers OS details, CPU, RAM, disk usage, network configuration,
    and saves a formatted report to a timestamped file.

.EXAMPLE
    .\SystemHealth.ps1
    Runs with default settings, saves report to C:\Reports.
#>

# Define output path with timestamp
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$OutputPath = "C:\Reports"
$ReportName = "SystemHealth_$Timestamp.txt"
$FullReportPath = Join-Path -Path $OutputPath -ChildPath $ReportName

# Create the output directory if it doesn't exist
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    Write-Host "[INFO] Created directory: $OutputPath" -ForegroundColor Green
}

# GATHER SYSTEM INFORMATION

# 1. Operating System
$OS = Get-CimInstance -ClassName Win32_OperatingSystem
$OSName = $OS.Caption
$OSVersion = $OS.Version
$OSBuild = $OS.BuildNumber
$LastBoot = $OS.LastBootUpTime

# 2. Computer Name
$ComputerName = $env:COMPUTERNAME
$UserName = $env:USERNAME

# 3. CPU
$CPU = Get-CimInstance -ClassName Win32_Processor
$CPUName = $CPU.Name
$CPUCores = $CPU.NumberOfCores
$CPUThreads = $CPU.NumberOfLogicalProcessors
$CPULoad = $CPU.LoadPercentage

# 4. RAM
$Memory = Get-CimInstance -ClassName Win32_PhysicalMemory
$TotalRAMGB = [math]::Round(($Memory.Capacity | Measure-Object -Sum).Sum / 1GB, 2)
$OSMem = Get-CimInstance -ClassName Win32_OperatingSystem
$FreeRAMGB = [math]::Round($OSMem.FreePhysicalMemory / 1MB, 2)
$UsedRAMGB = [math]::Round($TotalRAMGB - $FreeRAMGB, 2)
$RAMUsagePercent = [math]::Round(($UsedRAMGB / $TotalRAMGB) * 100, 2)

# 5. Disk Drives
$Disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
$DiskReport = foreach ($Disk in $Disks) {
    $FreeGB = [math]::Round($Disk.FreeSpace / 1GB, 2)
    $TotalGB = [math]::Round($Disk.Size / 1GB, 2)
    $UsedGB = [math]::Round($TotalGB - $FreeGB, 2)
    $UsagePercent = [math]::Round(($UsedGB / $TotalGB) * 100, 2)
    [PSCustomObject]@{
        Drive = $Disk.DeviceID
        TotalGB = $TotalGB
        UsedGB = $UsedGB
        FreeGB = $FreeGB
        UsagePercent = $UsagePercent
    }
}

# 6. Network Adapters
$Adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
$NetworkReport = foreach ($Adapter in $Adapters) {
    $IP = Get-NetIPAddress -InterfaceIndex $Adapter.InterfaceIndex -AddressFamily IPv4 | Select-Object -First 1
    [PSCustomObject]@{
        AdapterName = $Adapter.Name
        MACAddress = $Adapter.MacAddress
        IPAddress = $IP.IPAddress
        Status = $Adapter.Status
    }
}

# BUILD THE REPORT
$Report = @"
================================================================================
                         SYSTEM HEALTH REPORT
================================================================================
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer:  $ComputerName
User:      $UserName

--------------------------------------------------------------------------------
1. OPERATING SYSTEM
--------------------------------------------------------------------------------
OS Name:          $OSName
Version:          $OSVersion
Build Number:     $OSBuild
Last Boot Time:   $LastBoot

--------------------------------------------------------------------------------
2. PROCESSOR (CPU)
--------------------------------------------------------------------------------
CPU:              $CPUName
Cores:            $CPUCores
Logical Threads:  $CPUThreads
Current Load:     $CPULoad%

--------------------------------------------------------------------------------
3. MEMORY (RAM)
--------------------------------------------------------------------------------
Total RAM:        $TotalRAMGB GB
Used RAM:         $UsedRAMGB GB
Free RAM:         $FreeRAMGB GB
Usage:            $RAMUsagePercent%

--------------------------------------------------------------------------------
4. DISK USAGE
--------------------------------------------------------------------------------
$($DiskReport | Format-Table -AutoSize | Out-String)

--------------------------------------------------------------------------------
5. NETWORK ADAPTERS
--------------------------------------------------------------------------------
$($NetworkReport | Format-Table -AutoSize | Out-String)

================================================================================
                               END OF REPORT
================================================================================
"@

# SAVE THE REPORT
$Report | Out-File -FilePath $FullReportPath -Encoding UTF8

# CONFIRMATION
Write-Host "[SUCCESS] Report saved to: $FullReportPath" -ForegroundColor Cyan
Write-Host "[INFO] File size: $((Get-Item $FullReportPath).Length) bytes" -ForegroundColor Yellow

# OPTIONAL: Open the report automatically
# notepad $FullReportPath