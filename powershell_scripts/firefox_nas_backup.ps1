# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script backs up the default Firefox profile to a Linux-based NAS. By default, it excludes unnecessary cache/temp/log files, but users can override this to include all files/folders by running the script as follows:
# .\firefox_nas_backup.ps1 -ExcludeCache:$false

# Robocopy exit code list:
# Exit Code Meaning
# 0			No files copied (no failures)
# 1			One or more files copied successfully (no failures)
# 2			Extra files or directories detected (deleted if /MIR is used)
# 3			Files copied and extra files/directories deleted (1 + 2)
# 4–7		Success with minor issues (mismatched files, skipped files, retryable errors)
# 8+		Failure — serious errors (network issue, permissions, etc.)
# NOTE: Exit codes 0–7 are generally considered successful for backup validation

param (
	[switch]$ExcludeCache = $true # Default to excluding cache/temp/log files
)

# Specify remote directory to copy to and the NAS hostname
$Destination = "\\NAS\PATH\TO\FIREFOX_BACKUP_DIRECTORY" # Change this to your NAS Firefox backup directory
$nasHost = "NAS_HOSTNAME" # Change this to your NAS hostname

# Quick NAS Availability Check
Write-Host "Checking NAS availability ($nasHost)..." -ForegroundColor Cyan

if (-not (Test-Connection -ComputerName $nasHost -Count 1 -Quiet)) {
	Write-Host "`nBackup aborted: $nasHost is not reachable." -ForegroundColor Red
	return
}
else {
	Write-Host "$nasHost is reachable." -ForegroundColor Green
}

# Detect if Firefox is running and close it if y/Y is pressed (otherwise abort)
$firefoxProcess = Get-Process -Name firefox -ErrorAction SilentlyContinue

if ($firefoxProcess) {
	$response = Read-Host "`nFirefox is currently running. Close Firefox now? (Y/N)"

	if ($response -match '^[Yy]$') {
		Write-Host "Stopping Firefox..." -ForegroundColor Cyan
		Stop-Process -Name firefox -Force
		Start-Sleep -Seconds 2
	}
	else {
		Write-Host "`nBackup aborted: Please re-run the script and select 'Y' to close Firefox, or close Firefox manually before running again." -ForegroundColor Red
		return
	}
}

# Locate profiles.ini
$profilesIni = Join-Path $env:APPDATA "Mozilla\Firefox\profiles.ini"

if (-not (Test-Path $profilesIni)) {
	Write-Host "profiles.ini not found." -ForegroundColor Red
	return
}

# Parse Default Profile
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
	Write-Host "Default profile not found." -ForegroundColor Red
	return
}

if ($isRelative) {
	$Source = Join-Path $env:APPDATA "Mozilla\Firefox\$profilePath"
}
else {
	$Source = $profilePath
}

if (-not (Test-Path $Source)) {
	Write-Host "Profile path not found: $Source" -ForegroundColor Red
	return
}

Write-Host "`nSource Profile: $Source" -ForegroundColor Green
Write-Host "Destination: $Destination`n" -ForegroundColor Green

# Build Robocopy Arguments
# NOTE: There is no need to delete the existing backup folder from the destination folder before starting the backup. The /MIR (mirror) flag in Robocopy ensures the backup folder always matches the source profile exactly — it copies new/updated files and removes any files that no longer exist in the source. This safely maintains a single up-to-date backup at all times.
$robocopyArgs = @(
	$Source,
	$Destination,
	"/MIR",
	"/FFT",
	"/R:1",
	"/W:1"
)

# OPTIONAL: Exclude cache/temp/log files
# If $ExcludeCache = $true is specified (default behavior), the following folders and files will NOT be copied to the backup:
# Folders excluded: cache2, startupCache, minidumps, crashes, thumbnails, shader-cache, storage\temporary, weave\logs
# Files excluded: parent.lock, lock, .lock, *.log
# This keeps the backup clean by skipping transient or rebuildable data while preserving all important profile data (bookmarks, passwords, extensions, cookies, sessionstore, etc.)
if ($ExcludeCache) {
	$robocopyArgs += "/XD", "cache2", "crashes", "minidumps", "shader-cache", "startupCache", "storage\temporary", "thumbnails", "weave\logs"
	$robocopyArgs += "/XF", "*.log", ".lock", "lock", "parent.lock"
}

# Execute Robocopy
Write-Host "Starting Firefox profile backup..." -ForegroundColor Cyan
robocopy @robocopyArgs

$exitCode = $LASTEXITCODE

if ($exitCode -le 3) {
	Write-Host "`nFirefox profile backup completed successfully (Robocopy exit code: $exitCode)." -ForegroundColor Green
}
else {
	Write-Host "`nFirefox profile backup completed with errors (Robocopy exit code: $exitCode)." -ForegroundColor Red
}

# End.