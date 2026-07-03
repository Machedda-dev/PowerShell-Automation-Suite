# System Health Reporter

A PowerShell script that collects comprehensive system information and generates a timestamped health report.

## Features

- **OS Information**: Version, build number, last boot time
- **CPU**: Name, cores, threads, current load percentage
- **RAM**: Total, used, free, and usage percentage
- **Disk Drives**: Per-drive usage (Total, Used, Free, Usage %)
- **Network Adapters**: Name, MAC address, IP address, status
- **Auto-Timestamped Reports**: Never overwrite old reports
- **Organized Output**: Saves reports to `C:\Reports` by default

## Usage

### Basic Usage
```powershell
.\SystemHealth.ps1
```

This generates a report at: `C:\Reports\SystemHealth_YYYY-MM-DD_HH-MM-SS.txt`

### Custom Output Path
```powershell
.\SystemHealth.ps1 -OutputPath "D:\MyReports"
```

## Example Output

```
================================================================================
                         SYSTEM HEALTH REPORT
================================================================================
Generated: 2026-07-01 10:14:26
Computer:  DESKTOP-ABC123
User:      YourName

--------------------------------------------------------------------------------
1. OPERATING SYSTEM
--------------------------------------------------------------------------------
OS Name:          Microsoft Windows 10 Pro
Version:          10.0.19045
...
```

## Requirements

- Windows 7/8/10/11
- PowerShell 5.1 or higher
- Run as Administrator (recommended)


AUTHOR
VINCENT ODODA-[linkedin/portfolio link]

License: MIT