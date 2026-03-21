# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script backs up the default Google Chrome profile to a Linux-based NAS. By default, it excludes unnecessary cache/temp/log files, but users can override this to include all files/folders by running the script as follows:
# .\chrome_nas_backup.ps1 -IncludeCache

# Robocopy exit code list:
# Exit Code Meaning
# 0			No files copied (no failures)
# 1			One or more files copied successfully (no failures)
# 2			Extra files or directories detected (deleted if /MIR is used)
# 3			Files copied and extra files/directories deleted (1 + 2)
# 4–7		Success with minor issues (mismatched files, skipped files, retryable errors)
# 8+		Failure — serious errors (network issue, permissions, etc.)
# NOTE: Exit codes 0–7 are generally considered successful for backup validation

# Optional flags:
#     -IncludeCache: Include cache/temp/log files in backup (excluded by default)
#     -Help / -?: Display this help message

[CmdletBinding()]
param (
	[switch]$IncludeCache, # Include cache/temp/log files in backup (excluded by default)
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-IncludeCache] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -IncludeCache  Include cache/temp/log files in backup (excluded by default)" -ForegroundColor Cyan
	Write-Host "  -Help          Display this help message" -ForegroundColor Cyan
	Write-Host "" # extra newline for readability
	exit 0
}

# Specify remote directory to copy to and the NAS hostname
$Destination = "\\NAS\PATH\TO\CHROME_BACKUP_DIRECTORY" # Change this to your NAS Chrome backup directory
$nasHost = "NAS_HOSTNAME" # Change this to your NAS hostname

# Quick NAS availability check
Write-Host "`nChecking NAS availability ($nasHost)..." -ForegroundColor Cyan
if (-not (Test-Connection -ComputerName $nasHost -Count 1 -Quiet)) {
	Write-Host "`nBackup aborted: $nasHost is not reachable." -ForegroundColor Red
	return
}
else {
	Write-Host "$nasHost is reachable." -ForegroundColor Green
}

# Detect if Chrome is running and close it if y/Y is pressed (otherwise abort)
$chromeProcess = Get-Process -Name chrome -ErrorAction SilentlyContinue
if ($chromeProcess) {
	$response = Read-Host "`nGoogle Chrome is currently running. Close Chrome now? (Y/N)"
	if ($response -match '^[Yy]$') {
		Write-Host "`nStopping Chrome..." -ForegroundColor Cyan
		Stop-Process -Name chrome -Force
		Start-Sleep -Seconds 2
	}
	else {
		Write-Host "`nBackup aborted: Please re-run the script and select 'Y' to close Chrome, or close Chrome manually before running again." -ForegroundColor Red
		return
	}
}

# Define default Chrome profile path
$Source = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default"

if (-not (Test-Path $Source)) {
	Write-Host "Chrome profile path not found: $Source" -ForegroundColor Red
	return
}

Write-Host "`nSource Profile: $Source" -ForegroundColor Green
Write-Host "Destination: $Destination`n" -ForegroundColor Green

# Build Robocopy Arguments
# NOTE: There is no need to delete the existing backup folder from the destination folder before starting the backup
# The /MIR (mirror) flag in Robocopy ensures the backup folder always matches the source profile exactly — it copies new/updated files and removes any files that no longer exist in the source
# This safely maintains a single up-to-date backup at all times
$robocopyArgs = @(
	$Source,
	$Destination,
	"/MIR",
	"/FFT",
	"/R:1",
	"/W:1"
)

# OPTIONAL: Exclude cache/temp/log files
# If -IncludeCache is not specified (default behavior), the following folders and files will NOT be copied to the backup:
# Folders excluded: Cache, Code Cache, Crash Reports, GPUCache, JumpListIcons, Media Cache, Service Worker
# Files excluded: *.log
# This keeps the backup clean by skipping transient or rebuildable data while preserving all important profile data (Bookmarks, Extensions, Preferences, Cookies, History, Sessions, etc.)
if (-not $IncludeCache) {
	$robocopyArgs += "/XD", "Cache", "Code Cache", "Crash Reports", "GPUCache", "JumpListIcons", "Media Cache", "Service Worker"
	$robocopyArgs += "/XF", "*.log"
}

# Execute Robocopy
Write-Host "Starting Google Chrome profile backup..." -ForegroundColor Cyan
robocopy @robocopyArgs

$exitCode = $LASTEXITCODE
if ($exitCode -le 3) {
	Write-Host "`nGoogle Chrome profile backup completed successfully (Robocopy exit code: $exitCode)." -ForegroundColor Green
}
else {
	Write-Host "`nGoogle Chrome profile backup completed with errors (Robocopy exit code: $exitCode)." -ForegroundColor Red
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.