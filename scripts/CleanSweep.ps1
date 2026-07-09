<#
.SYNOPSIS
    Windows CleanSweep Toolkit - Safe Windows cleanup and leftover scanner.

.DESCRIPTION
    Scans common Windows junk locations and creates CSV/HTML reports.
    Cleanup mode removes only conservative temporary files older than the selected age.
    Designed for IT Support training, helpdesk labs and controlled troubleshooting.
#>

[CmdletBinding()]
param(
    [switch]$ScanOnly,
    [switch]$Clean,
    [int]$OlderThanDays = 3,
    [switch]$IncludeDeveloperCaches
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ReportDir = Join-Path $Root 'reports'
$LogDir = Join-Path $Root 'logs'
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$TimeStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$CsvReport = Join-Path $ReportDir "CleanSweep_Report_$TimeStamp.csv"
$HtmlReport = Join-Path $ReportDir "CleanSweep_Report_$TimeStamp.html"
$LogFile = Join-Path $LogDir "CleanSweep_$TimeStamp.log"

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    $line | Tee-Object -FilePath $LogFile -Append
}

function Show-Banner {
    Write-Host ''
    Write-Host '============================================' -ForegroundColor Cyan
    Write-Host ' Windows CleanSweep Toolkit' -ForegroundColor Cyan
    Write-Host ' Safe Cleanup and Disk Analysis' -ForegroundColor Cyan
    Write-Host '============================================' -ForegroundColor Cyan
    Write-Host ''
}

function Get-FolderSize {
    param([string]$Path)
    try {
        if (-not (Test-Path $Path)) { return 0 }
        $sum = 0
        Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | ForEach-Object { $sum += $_.Length }
        return $sum
    } catch {
        return 0
    }
}

function Convert-Size {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Add-Result {
    param(
        [string]$Category,
        [string]$Path,
        [string]$Action,
        [string]$Risk,
        [double]$SizeBytes,
        [string]$Notes
    )
    [PSCustomObject]@{
        Category = $Category
        Path = $Path
        Action = $Action
        Risk = $Risk
        Size = Convert-Size $SizeBytes
        SizeBytes = [math]::Round($SizeBytes, 0)
        Notes = $Notes
    }
}

function Remove-OldTempFiles {
    param([string]$Path, [int]$Days)
    if (-not (Test-Path $Path)) { return }
    $cutoff = (Get-Date).AddDays(-$Days)
    Write-Log "Cleaning old temp files in $Path older than $Days days"
    Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { -not $_.PSIsContainer -and $_.LastWriteTime -lt $cutoff } |
        ForEach-Object {
            try {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
                Write-Log "Deleted: $($_.FullName)"
            } catch {
                Write-Log "Skipped locked/protected file: $($_.FullName)" 'WARN'
            }
        }
}

Show-Banner
Write-Log 'Started Windows CleanSweep Toolkit'

$results = @()
$userTemp = $env:TEMP
$windowsTemp = Join-Path $env:WINDIR 'Temp'
$updateCache = Join-Path $env:WINDIR 'SoftwareDistribution\Download'
$downloads = Join-Path $env:USERPROFILE 'Downloads'
$desktop = [Environment]::GetFolderPath('Desktop')
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu'

$scanTargets = @(
    @{Category='User Temp Files'; Path=$userTemp; Action='Safe cleanup candidate'; Risk='Low'; Notes='Old files can usually be removed safely.'},
    @{Category='Windows Temp Files'; Path=$windowsTemp; Action='Safe cleanup candidate'; Risk='Low'; Notes='May contain locked system files; locked files are skipped.'},
    @{Category='Windows Update Cache'; Path=$updateCache; Action='Report only'; Risk='Medium'; Notes='Use Windows cleanup tools or stop services before manual cleanup.'},
    @{Category='Downloads Folder'; Path=$downloads; Action='Review only'; Risk='High'; Notes='User data. Never delete automatically.'}
)

foreach ($target in $scanTargets) {
    $size = Get-FolderSize $target.Path
    $results += Add-Result -Category $target.Category -Path $target.Path -Action $target.Action -Risk $target.Risk -SizeBytes $size -Notes $target.Notes
}

$browserCaches = @(
    @{Name='Microsoft Edge Cache'; Path=Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default\Cache'},
    @{Name='Google Chrome Cache'; Path=Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default\Cache'},
    @{Name='Firefox Profiles'; Path=Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'}
)

foreach ($cache in $browserCaches) {
    $size = Get-FolderSize $cache.Path
    $results += Add-Result -Category $cache.Name -Path $cache.Path -Action 'Report only' -Risk 'Medium' -SizeBytes $size -Notes 'Close browser before cleanup. This toolkit reports browser cache by default.'
}

$dumpPaths = @(
    Join-Path $env:WINDIR 'MEMORY.DMP',
    Join-Path $env:WINDIR 'Minidump'
)
foreach ($dump in $dumpPaths) {
    $size = Get-FolderSize $dump
    $results += Add-Result -Category 'Crash Dumps' -Path $dump -Action 'Review only' -Risk 'Medium' -SizeBytes $size -Notes 'Useful for troubleshooting BSOD before deletion.'
}

$shortcutRoots = @($desktop, $startMenu)
foreach ($rootPath in $shortcutRoots) {
    if (Test-Path $rootPath) {
        $broken = 0
        Get-ChildItem -Path $rootPath -Filter *.lnk -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($_.FullName)
                if ($shortcut.TargetPath -and -not (Test-Path $shortcut.TargetPath)) { $broken++ }
            } catch {}
        }
        $results += Add-Result -Category 'Broken Shortcuts' -Path $rootPath -Action 'Review only' -Risk 'Low' -SizeBytes 0 -Notes "$broken broken shortcut(s) found."
    }
}

$startupPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$startupCount = 0
if (Test-Path $startupPath) { $startupCount = @(Get-ChildItem $startupPath -ErrorAction SilentlyContinue).Count }
$results += Add-Result -Category 'Startup Items' -Path $startupPath -Action 'Review only' -Risk 'Medium' -SizeBytes 0 -Notes "$startupCount startup item(s) found."

$pathEntries = ($env:Path -split ';') | Where-Object { $_ }
$deadPathCount = @($pathEntries | Where-Object { -not (Test-Path $_) }).Count
$results += Add-Result -Category 'Dead PATH Entries' -Path 'Environment PATH' -Action 'Review only' -Risk 'Medium' -SizeBytes 0 -Notes "$deadPathCount missing PATH location(s) found."

if ($IncludeDeveloperCaches) {
    $devCaches = @(
        @{Name='npm cache'; Path=Join-Path $env:APPDATA 'npm-cache'},
        @{Name='pip cache'; Path=Join-Path $env:LOCALAPPDATA 'pip\cache'},
        @{Name='NuGet cache'; Path=Join-Path $env:USERPROFILE '.nuget\packages'}
    )
    foreach ($dev in $devCaches) {
        $size = Get-FolderSize $dev.Path
        $results += Add-Result -Category $dev.Name -Path $dev.Path -Action 'Report only' -Risk 'Medium' -SizeBytes $size -Notes 'Developer cache. Clean manually if you understand the impact.'
    }
}

$results | Sort-Object SizeBytes -Descending | Export-Csv -Path $CsvReport -NoTypeInformation -Encoding UTF8
$results | Sort-Object SizeBytes -Descending | ConvertTo-Html -Title 'Windows CleanSweep Report' -PreContent '<h1>Windows CleanSweep Report</h1>' | Out-File -FilePath $HtmlReport -Encoding UTF8

Write-Host "Reports created:" -ForegroundColor Green
Write-Host "CSV : $CsvReport"
Write-Host "HTML: $HtmlReport"

if ($Clean) {
    Write-Host ''
    Write-Host 'Safe cleanup mode will delete old files only from:' -ForegroundColor Yellow
    Write-Host "- $userTemp"
    Write-Host "- $windowsTemp"
    Write-Host "Older than $OlderThanDays days."
    $confirm = Read-Host 'Type YES to continue'
    if ($confirm -eq 'YES') {
        Remove-OldTempFiles -Path $userTemp -Days $OlderThanDays
        Remove-OldTempFiles -Path $windowsTemp -Days $OlderThanDays
        Write-Host 'Cleanup completed. Some locked files may have been skipped.' -ForegroundColor Green
        Write-Log 'Cleanup completed'
    } else {
        Write-Host 'Cleanup cancelled.' -ForegroundColor Yellow
        Write-Log 'Cleanup cancelled by user'
    }
} else {
    Write-Host 'Scan completed. No files were deleted.' -ForegroundColor Cyan
}

Write-Log 'Finished Windows CleanSweep Toolkit'
