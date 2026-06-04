# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script backs up the default Thunderbird profile to a Linux-based NAS. By default, it excludes unnecessary cache/temp/log files, but users can override this to include all files/folders by running the script as follows:
# .\thunderbird_nas_backup.ps1 -IncludeCache

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

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$IncludeCache,
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
	Write-Host ""  # extra newline for readability
	exit 0
}

# Specify remote directory to copy to and the NAS hostname
$Destination = "\\NAS\PATH\TO\THUNDERBIRD_BACKUP_DIRECTORY"  # Change this to your NAS Thunderbird backup directory
$nasHost = "NAS_HOSTNAME"  # Change this to your NAS hostname

# Quick NAS availability check
Write-Host "`nChecking NAS availability ($nasHost)..." -ForegroundColor Cyan
if (-not (Test-Connection -ComputerName $nasHost -Count 1 -Quiet)) {
	Write-Host ""
	Write-Error "Backup aborted: $nasHost is not reachable."
	exit 1
}
Write-Host "$nasHost is reachable." -ForegroundColor Green

# Detect if Thunderbird is running and close it if y/Y is pressed (otherwise abort)
$thunderbirdProcess = Get-Process -Name thunderbird -ErrorAction SilentlyContinue
if ($thunderbirdProcess) {
	$response = Read-Host "`nThunderbird is currently running. Close Thunderbird now? (Y/N)"
	if ($response -match '^[Yy]$') {
		Write-Host "`nStopping Thunderbird..." -ForegroundColor Cyan
		Stop-Process -Name thunderbird -Force
		Start-Sleep -Seconds 2
	}
	else {
		Write-Host ""
		Write-Error "Backup aborted: Please re-run the script and select 'Y' to close Thunderbird, or close Thunderbird manually before running again."
		exit 1
	}
}

# Locate profiles.ini
$profilesIni = Join-Path $env:APPDATA "Thunderbird\profiles.ini"

if (-not (Test-Path $profilesIni)) {
	Write-Host ""
	Write-Error "profiles.ini not found."
	exit 1
}

# Parse Default profile
$profilePath = $null
$isRelative = $true
$lines = Get-Content $profilesIni

for ($i = 0; $i -lt $lines.Count; $i++) {
	if ($lines[$i] -match "Default=1") {
		for ($j = $i; $j -ge 0; $j--) {
			if ($lines[$j] -match "^Path=") {
				$profilePath = $lines[$j] -replace "^Path=", ""
			}
			if ($lines[$j] -match "^IsRelative=") {
				$isRelative = [bool]([int]($lines[$j] -replace "^IsRelative=", ""))
			}
		}
		break
	}
}

if (-not $profilePath) {
	Write-Host ""
	Write-Error "Default profile not found."
	exit 1
}

if ($isRelative) {
	$Source = Join-Path $env:APPDATA "Thunderbird\$profilePath"
}
else {
	$Source = $profilePath
}

if (-not (Test-Path $Source)) {
	Write-Host ""
	Write-Error "Profile path not found: $Source"
	exit 1
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
# Folders excluded: cache2, crashes, minidumps, thumbnails, storage\temporary
# Files excluded: *.log, .lock, lock, parent.lock
# This keeps the backup clean by skipping transient or rebuildable data while preserving all important profile data (emails, settings, extensions, address books, etc.)
if (-not $IncludeCache) {
	$robocopyArgs += "/XD", "cache2", "crashes", "minidumps", "thumbnails", "storage\temporary"
	$robocopyArgs += "/XF", "*.log", ".lock", "lock", "parent.lock"
}

# Execute Robocopy
Write-Host "Starting Thunderbird profile backup..." -ForegroundColor Cyan
$robocopyOutput = robocopy @robocopyArgs
$exitCode = $LASTEXITCODE
Write-Host ($robocopyOutput -join "`n").TrimEnd()
if ($exitCode -le 3) {
	Write-Host "`nThunderbird profile backup completed successfully (Robocopy exit code: $exitCode)." -ForegroundColor Green
	exit 0
}
else {
	Write-Host ""
	Write-Warning "Thunderbird profile backup completed with errors (Robocopy exit code: $exitCode)."
	exit 1
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.