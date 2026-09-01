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

# NOTE: Exit codes 0–7 are generally considered successful for backup validation (only bit value 8 indicates an actual copy failure); this is reflected in the exit code check below

# Optional flags:
#     -Force:              Automatically close Chrome if running, without prompting
#     -IncludeCache:       Include cache/temp/log files in backup (excluded by default)
#     -NoConsoleOutput:    Suppress console output (requires -SaveResults, and one of -Force/-Preview)
#     -Preview:            Show what would happen without running the backup
#     -SaveResults <PATH>: Save results to a text file (appends if file exists)
#     -Help / -?:          Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Force,
	[switch]$IncludeCache,
	[switch]$NoConsoleOutput,
	[switch]$Preview,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Force] [-IncludeCache] [-NoConsoleOutput] [-Preview] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Force               Automatically close Chrome if running, without prompting" -ForegroundColor Cyan
	Write-Host "  -IncludeCache        Include cache/temp/log files in backup (excluded by default)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -SaveResults, and one of -Force/-Preview)" -ForegroundColor Cyan
	Write-Host "  -Preview             Show what would happen without running the backup" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (appends if file exists)" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# -NoConsoleOutput requires -SaveResults, and one of -Force or -Preview, since without one of
# those this script can still block on an interactive prompt with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not ($Force -or $Preview) -or -not $SaveResults)) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults, and one of -Force or -Preview."
	exit 1
}

# Validate -SaveResults path if specified
if ($SaveResults) {
	$saveDir = Split-Path $SaveResults -Parent
	if ($saveDir -and -not (Test-Path $saveDir)) {
		Write-Host ""
		Write-Error "The directory for -SaveResults does not exist: '$saveDir'"
		exit 1
	}

	# Write the hostname as a header line the first time this file is created, so a fleet of per-machine files can be identified at a glance
	if (-not (Test-Path $SaveResults)) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$env:COMPUTERNAME`:`n")
		}
		catch {
			Write-Host ""
			Write-Warning "Could not write hostname header to '$SaveResults': $($_.Exception.Message)"
		}
	}
}

$resultLines = @()

# Specify remote directory to copy to and the NAS hostname
$Destination = "\\NAS\PATH\TO\CHROME_BACKUP_DIRECTORY"  # Change this to your NAS Chrome backup directory
$nasHost = "NAS_HOSTNAME"  # Change this to your NAS hostname

# Quick NAS availability check
if (-not $NoConsoleOutput) { Write-Host "`nChecking NAS availability ($nasHost)..." -ForegroundColor Cyan }
if (-not (Test-Connection -ComputerName $nasHost -Count 1 -Quiet)) {
	$errorMessage = "$ScriptName`: [$env:COMPUTERNAME] Backup aborted: $nasHost is not reachable."
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Error $errorMessage
	}
	if ($SaveResults) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$errorMessage`n")
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}
	exit 1
}
if (-not $NoConsoleOutput) { Write-Host "$nasHost is reachable." -ForegroundColor Green }

# Detect if Chrome is running and close it if y/Y is pressed, -Force is specified, or report it under -Preview (otherwise abort)
$chromeProcess = Get-Process -Name chrome -ErrorAction SilentlyContinue
if ($chromeProcess) {
	if ($Preview) {
		if (-not $NoConsoleOutput) { Write-Host "`nGoogle Chrome is currently running. It would be closed before backing up." -ForegroundColor Yellow }
		$resultLines += "Google Chrome is currently running. It would be closed before backing up."
	}
	elseif ($Force) {
		if (-not $NoConsoleOutput) { Write-Host "`nStopping Chrome..." -ForegroundColor Cyan }
		Stop-Process -Name chrome -Force
		Start-Sleep -Seconds 2
	}
	else {
		$response = Read-Host "`nGoogle Chrome is currently running. Close Chrome now? (Y/N)"
		if ($response -match '^[Yy]$') {
			Write-Host "`nStopping Chrome..." -ForegroundColor Cyan
			Stop-Process -Name chrome -Force
			Start-Sleep -Seconds 2
		}
		else {
			Write-Host ""
			Write-Error "Backup aborted: Please re-run the script and select 'Y' to close Chrome, or close Chrome manually before running again."
			exit 1
		}
	}
}

# Define default Chrome profile path
$Source = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default"

if (-not (Test-Path $Source)) {
	$errorMessage = "$ScriptName`: [$env:COMPUTERNAME] Chrome profile path not found: $Source"
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Error $errorMessage
	}
	if ($SaveResults) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$errorMessage`n")
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}
	exit 1
}

if (-not $NoConsoleOutput) {
	Write-Host "`nSource Profile: $Source" -ForegroundColor Green
	Write-Host "Destination: $Destination`n" -ForegroundColor Green
}

# Build Robocopy arguments
# NOTE: There is no need to delete the existing backup folder from the destination folder before starting the backup
# The /MIR (mirror) flag in Robocopy ensures the backup folder always matches the source profile exactly — it copies new/updated files and removes any files that no longer exist in the source
# This safely maintains a single up-to-date backup at all times. Robocopy also creates the destination folder automatically if it does not already exist.
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

# Preview mode: show what would happen without running Robocopy
if ($Preview) {
	# Quote any argument containing a space so the displayed command is accurate if copy-pasted, even though the real robocopy call below passes $robocopyArgs as a proper array regardless
	$displayArgs = $robocopyArgs | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Preview complete. Would back up '$Source' to '$Destination' (robocopy $($displayArgs -join ' ')). No files were copied."
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Yellow }
	$resultLines += $summaryLine

	if ($SaveResults) {
		try {
			$content = ($resultLines -join "`n") + "`n"
			[System.IO.File]::AppendAllText($SaveResults, $content)
			if (-not $NoConsoleOutput) { Write-Host "`nResults saved to: $SaveResults" -ForegroundColor Green }
		}
		catch {
			# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}

	exit 0
}

# Execute Robocopy
if (-not $NoConsoleOutput) { Write-Host "Starting Google Chrome profile backup..." -ForegroundColor Cyan }
$robocopyOutput = robocopy @robocopyArgs
$exitCode = $LASTEXITCODE
if (-not $NoConsoleOutput) { Write-Host ($robocopyOutput -join "`n").TrimEnd() }

# Only exit code 8+ indicates an actual copy failure; 0-7 are various combinations of successful /MIR activity (see exit code NOTE above)
if ($exitCode -le 7) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Google Chrome profile backup completed successfully (Robocopy exit code: $exitCode)."
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }
	$resultLines += $summaryLine
	$finalExitCode = 0
}
else {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Google Chrome profile backup completed with errors (Robocopy exit code: $exitCode)."
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Warning $summaryLine
	}
	$resultLines += $summaryLine
	$finalExitCode = 1
}

if ($SaveResults) {
	try {
		$content = ($resultLines -join "`n") + "`n"
		[System.IO.File]::AppendAllText($SaveResults, $content)
		if (-not $NoConsoleOutput) { Write-Host "`nResults saved to: $SaveResults" -ForegroundColor Green }
	}
	catch {
		# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

exit $finalExitCode

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.