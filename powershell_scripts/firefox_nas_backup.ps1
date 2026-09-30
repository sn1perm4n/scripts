# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script backs up the default Firefox profile to a Linux-based NAS. By default, it excludes unnecessary cache/temp/log files, but users can override this to include all files/folders by running the script as follows:
# .\firefox_nas_backup.ps1 -IncludeCache

# Robocopy exit code list:
# Exit Code Meaning
# 0			No files copied (no failures)
# 1			One or more files copied successfully (no failures)
# 2			Extra files or directories detected (deleted if /MIR is used)
# 3			Files copied and extra files/directories deleted (1 + 2)
# 4–7		Success with minor issues (mismatched files, skipped files, retryable errors)
# 8+		Failure — serious errors (network issue, permissions, etc.)
# NOTE: Exit codes 0–7 are generally considered successful for backup validation (only bit value 8 indicates an actual copy failure); this is reflected in the exit code check below

# NOTE2: -Extensions performs a narrower backup of just the extensions folder's .xpi files instead of the full profile backup, for anyone who doesn't want their entire profile backed up; the "staged" subfolder is excluded since it only ever contains empty subfolders

# Optional flags:
#     -Extensions:           Back up only the extensions folder's .xpi files (excluding the empty "staged" subfolder) instead of the full profile; replaces the normal backup for that run
#     -Force:                Automatically close Firefox if running, without prompting
#     -IncludeCache:         Include cache/temp/log files in backup (excluded by default; has no effect with -Extensions)
#     -NoConsoleOutput:      Suppress console output (requires -SaveResults, and one of -Force/-Preview)
#     -Preview:              Show what would happen without running the backup
#     -SaveResults <PATH>:   Save results to a text file (appends if file exists)
#     -Help / -?:            Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Extensions,
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
	Write-Host "`nUsage:`n    .\$ScriptName [-Extensions] [-Force] [-IncludeCache] [-NoConsoleOutput] [-Preview] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Extensions          Back up only the extensions folder's .xpi files (excluding the empty ""staged"" subfolder) instead of the full profile; replaces the normal backup for that run" -ForegroundColor Cyan
	Write-Host "  -Force               Automatically close Firefox if running, without prompting" -ForegroundColor Cyan
	Write-Host "  -IncludeCache        Include cache/temp/log files in backup (excluded by default; has no effect with -Extensions)" -ForegroundColor Cyan
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

# -IncludeCache has no effect with -Extensions, since the extensions-only backup doesn't touch the full-profile robocopy call at all
if ($Extensions -and $IncludeCache) {
	Write-Host ""
	Write-Warning "-IncludeCache has no effect with -Extensions."
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
$Destination = "\\NAS\PATH\TO\FIREFOX_BACKUP_DIRECTORY"  # Change this to your NAS Firefox backup directory
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

# Detect if Firefox is running and close it if y/Y is pressed, -Force is specified, or report it under -Preview (otherwise abort)
$firefoxProcess = Get-Process -Name firefox -ErrorAction SilentlyContinue
if ($firefoxProcess) {
	if ($Preview) {
		if (-not $NoConsoleOutput) { Write-Host "`nFirefox is currently running. It would be closed before backing up." -ForegroundColor Yellow }
		$resultLines += "Firefox is currently running. It would be closed before backing up."
	}
	elseif ($Force) {
		if (-not $NoConsoleOutput) { Write-Host "`nStopping Firefox..." -ForegroundColor Cyan }
		Stop-Process -Name firefox -Force
		Start-Sleep -Seconds 2
	}
	else {
		$response = Read-Host "`nFirefox is currently running. Close Firefox now? (Y/N)"
		if ($response -match '^[Yy]$') {
			Write-Host "`nStopping Firefox..." -ForegroundColor Cyan
			Stop-Process -Name firefox -Force
			Start-Sleep -Seconds 2
		}
		else {
			Write-Host ""
			Write-Error "Backup aborted: Please re-run the script and select 'Y' to close Firefox, or close Firefox manually before running again."
			exit 1
		}
	}
}

# Locate profiles.ini
$profilesIni = Join-Path $env:APPDATA "Mozilla\Firefox\profiles.ini"

if (-not (Test-Path $profilesIni)) {
	$errorMessage = "$ScriptName`: [$env:COMPUTERNAME] profiles.ini not found: $profilesIni"
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

# Parse Default profile
$profilePath = $null
$isRelative = $true

try {
	$lines = @(Get-Content $profilesIni -ErrorAction Stop)
}
catch {
	$errorMessage = "$ScriptName`: [$env:COMPUTERNAME] Could not read profiles.ini: $($_.Exception.Message)"
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

for ($i = 0; $i -lt $lines.Count; $i++) {
	if ($lines[$i] -match "Default=1") {
		# Scan backward from the Default=1 line, but stop at the start of this profile's own section (a blank line or the next [Section] header above it)
		for ($j = $i; $j -ge 0; $j--) {
			if ($j -lt $i -and ($lines[$j].Trim() -eq '' -or $lines[$j] -match '^\[')) {
				break
			}
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
	$errorMessage = "$ScriptName`: [$env:COMPUTERNAME] Default Firefox profile not found in profiles.ini."
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

if ($isRelative) {
	$Source = Join-Path $env:APPDATA "Mozilla\Firefox\$profilePath"
}
else {
	$Source = $profilePath
}

if (-not (Test-Path $Source)) {
	$errorMessage = "$ScriptName`: [$env:COMPUTERNAME] Profile path not found: $Source"
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
}

# -Extensions backs up only the extensions folder's .xpi files instead of the full profile
if ($Extensions) {
	$extensionsSource = Join-Path $Source "extensions"
	$extensionsDestination = Join-Path $Destination "extensions"

	if (-not (Test-Path $extensionsSource)) {
		$errorMessage = "$ScriptName`: [$env:COMPUTERNAME] Extensions folder not found: $extensionsSource"
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

	if (-not $NoConsoleOutput) { Write-Host "Destination: $extensionsDestination`n" -ForegroundColor Green }

	# Only .xpi files are copied, and the "staged" subfolder is excluded since it only ever contains empty subfolders
	$robocopyArgs = @(
		$extensionsSource,
		$extensionsDestination,
		"*.xpi",
		"/MIR",
		"/FFT",
		"/R:1",
		"/W:1",
		"/XD", "staged"
	)

	if ($Preview) {
		# Quote any argument containing a space so the displayed command is accurate if copy-pasted, even though the real robocopy call below passes $robocopyArgs as a proper array regardless
		$displayArgs = $robocopyArgs | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }
		$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Preview complete. Would back up extensions from '$extensionsSource' to '$extensionsDestination' (robocopy $($displayArgs -join ' ')). No files were copied."
		if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Yellow }
		$resultLines += $summaryLine

		if ($SaveResults) {
			try {
				$content = ($resultLines -join "`n") + "`n"
				[System.IO.File]::AppendAllText($SaveResults, $content)
				if (-not $NoConsoleOutput) { Write-Host "`nResults saved to: $SaveResults" -ForegroundColor Green }
			}
			catch {
				Write-Host ""
				Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
			}
		}
		exit 0
	}

	if (-not $NoConsoleOutput) { Write-Host "Starting Firefox extensions backup..." -ForegroundColor Cyan }
	$robocopyOutput = robocopy @robocopyArgs
	$exitCode = $LASTEXITCODE
	if (-not $NoConsoleOutput) { Write-Host ($robocopyOutput -join "`n").TrimEnd() }

	# Only exit code 8+ indicates an actual copy failure; 0-7 are various combinations of successful /MIR activity (see exit code NOTE above)
	if ($exitCode -le 7) {
		$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Firefox extensions backup completed successfully (Robocopy exit code: $exitCode)."
		if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }
		$resultLines += $summaryLine
		$finalExitCode = 0
	}
	else {
		$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Firefox extensions backup completed with errors (Robocopy exit code: $exitCode)."
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
}

if (-not $NoConsoleOutput) { Write-Host "Destination: $Destination`n" -ForegroundColor Green }

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
# Folders excluded: crashes, minidumps, startupCache, storage\temporary, thumbnails, weave\logs
# Files excluded: *.log, .lock, lock, parent.lock
# NOTE: Firefox stores its disk cache (cache2, shader-cache, etc.) in %LOCALAPPDATA%\Mozilla\Firefox\Profiles\<profile> rather than %APPDATA% where the profile personal data lives; the exclusions below target residual temp/log files that may exist in the %APPDATA% profile path
if (-not $IncludeCache) {
	$robocopyArgs += "/XD", "crashes", "minidumps", "startupCache", "storage\temporary", "thumbnails", "weave\logs"
	$robocopyArgs += "/XF", "*.log", ".lock", "lock", "parent.lock"
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
if (-not $NoConsoleOutput) { Write-Host "Starting Firefox profile backup..." -ForegroundColor Cyan }
$robocopyOutput = robocopy @robocopyArgs
$exitCode = $LASTEXITCODE
if (-not $NoConsoleOutput) { Write-Host ($robocopyOutput -join "`n").TrimEnd() }

# Only exit code 8+ indicates an actual copy failure; 0-7 are various combinations of successful /MIR activity (see exit code NOTE above)
if ($exitCode -le 7) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Firefox profile backup completed successfully (Robocopy exit code: $exitCode)."
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }
	$resultLines += $summaryLine
	$finalExitCode = 0
}
else {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Firefox profile backup completed with errors (Robocopy exit code: $exitCode)."
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