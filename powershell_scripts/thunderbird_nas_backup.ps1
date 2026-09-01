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
# NOTE: Exit codes 0–7 are generally considered successful for backup validation (only bit value 8 indicates an actual copy failure); this is reflected in the exit code check below

# NOTE2: Since Thunderbird 68, installs.ini tracks a per-installation default profile that can differ from profiles.ini's Default=1 marker. This script prefers installs.ini when exactly one installation is listed there, since the on-disk install-to-profile mapping cannot be otherwise determined from this script; it falls back to profiles.ini's Default=1 if installs.ini is absent, unreadable, lists multiple installations, or its recorded path does not exist.

# Optional flags:
#     -Force:              Automatically close Thunderbird if running, without prompting
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
	Write-Host "  -Force               Automatically close Thunderbird if running, without prompting" -ForegroundColor Cyan
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
$Destination = "\\NAS\PATH\TO\THUNDERBIRD_BACKUP_DIRECTORY"  # Change this to your NAS Thunderbird backup directory
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

# Detect if Thunderbird is running and close it if y/Y is pressed, -Force is specified, or report it under -Preview (otherwise abort)
$thunderbirdProcess = Get-Process -Name thunderbird -ErrorAction SilentlyContinue
if ($thunderbirdProcess) {
	if ($Preview) {
		if (-not $NoConsoleOutput) { Write-Host "`nThunderbird is currently running. It would be closed before backing up." -ForegroundColor Yellow }
		$resultLines += "Thunderbird is currently running. It would be closed before backing up."
	}
	elseif ($Force) {
		if (-not $NoConsoleOutput) { Write-Host "`nStopping Thunderbird..." -ForegroundColor Cyan }
		Stop-Process -Name thunderbird -Force
		Start-Sleep -Seconds 2
	}
	else {
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
}

# Try installs.ini first (see NOTE2), falling back to profiles.ini's Default=1 marker
$profilesIni = Join-Path $env:APPDATA "Thunderbird\profiles.ini"
$installsIni = Join-Path $env:APPDATA "Thunderbird\installs.ini"
$profilePath = $null
$isRelative = $true
$usedInstallsIni = $false

if (Test-Path $installsIni) {
	try {
		$installLines = @(Get-Content $installsIni -ErrorAction Stop)
		$installDefaults = @()
		foreach ($line in $installLines) {
			if ($line -match '^Default=(.+)$') {
				$installDefaults += $Matches[1]
			}
		}

		if ($installDefaults.Count -eq 1) {
			$candidatePath = $installDefaults[0]
			$candidateIsRelative = -not ($candidatePath -match '^[A-Za-z]:\\' -or $candidatePath.StartsWith('\\'))
			$resolvedCandidate = if ($candidateIsRelative) { Join-Path $env:APPDATA "Thunderbird\$candidatePath" } else { $candidatePath }

			if (Test-Path $resolvedCandidate) {
				$profilePath = $candidatePath
				$isRelative = $candidateIsRelative
				$usedInstallsIni = $true
			}
			else {
				if (-not $NoConsoleOutput) {
					Write-Host ""
					Write-Warning "installs.ini's default profile path does not exist on disk ('$resolvedCandidate'). Falling back to profiles.ini's Default=1 marker instead."
				}
			}
		}
		elseif ($installDefaults.Count -gt 1) {
			if (-not $NoConsoleOutput) {
				Write-Host ""
				Write-Warning "Multiple Thunderbird installations found in installs.ini; could not determine which applies to this installation. Falling back to profiles.ini's Default=1 marker instead."
			}
		}
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Could not read installs.ini: $($_.Exception.Message). Falling back to profiles.ini's Default=1 marker instead."
		}
	}
}

if (-not $usedInstallsIni) {
	if (-not (Test-Path $profilesIni)) {
		$errorMessage = "$ScriptName`: [$env:COMPUTERNAME] profiles.ini not found."
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

	try {
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
	}
	catch {
		$errorMessage = "$ScriptName`: [$env:COMPUTERNAME] Could not parse profiles.ini: $($_.Exception.Message)"
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
}

if (-not $profilePath) {
	$errorMessage = "$ScriptName`: [$env:COMPUTERNAME] Default profile not found."
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
	$Source = Join-Path $env:APPDATA "Thunderbird\$profilePath"
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
	Write-Host "Destination: $Destination`n" -ForegroundColor Green
}

# Build Robocopy Arguments
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
# Folders excluded: cache2, crashes, minidumps, thumbnails, storage\temporary
# Files excluded: *.log, .lock, lock, parent.lock
# This keeps the backup clean by skipping transient or rebuildable data while preserving all important profile data (emails, settings, extensions, address books, etc.)
if (-not $IncludeCache) {
	$robocopyArgs += "/XD", "cache2", "crashes", "minidumps", "thumbnails", "storage\temporary"
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
if (-not $NoConsoleOutput) { Write-Host "Starting Thunderbird profile backup..." -ForegroundColor Cyan }
$robocopyOutput = robocopy @robocopyArgs
$exitCode = $LASTEXITCODE
if (-not $NoConsoleOutput) { Write-Host ($robocopyOutput -join "`n").TrimEnd() }

# Only exit code 8+ indicates an actual copy failure; 0-7 are various combinations of successful /MIR activity (see exit code NOTE above)
if ($exitCode -le 7) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Thunderbird profile backup completed successfully (Robocopy exit code: $exitCode)."
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }
	$resultLines += $summaryLine
	$finalExitCode = 0
}
else {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Thunderbird profile backup completed with errors (Robocopy exit code: $exitCode)."
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