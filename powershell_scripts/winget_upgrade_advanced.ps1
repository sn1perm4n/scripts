# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script updates the winget source database and then runs the winget upgrade command so potential updates can be seen
# Individual packages can then be upgraded via their ID, i.e.: "winget upgrade Microsoft.VCRedist.2013.x86"
# If you want to upgrade everything, you can run "winget upgrade --all"
# Available commands: https://learn.microsoft.com/en-us/windows/package-manager/winget/upgrade
# winget pin add --id <APP_ID> - Disables version checking for said app (useful if you need to avoid upgrading specific applications)
# winget pin remove --id <APP_ID> - Removes a pinned app from winget
# winget pin list - Shows the current pinned app list

# NOTE: On a fresh system where winget has never been run, this script may appear to hang until the priming step completes. This ensures first-run agreements are accepted non-interactively using v1.28.220 flags.

# Optional flags:
#     -InstallIfMissing: Install winget if it is not found on the system
#     -LogToDesktop: Save results to a file named winget_<COMPUTERNAME>.txt on the desktop
#     -NoConsoleOutput: Suppress console output (requires -SaveResults); errors are redirected into the results file instead of being lost
#     -NoLog: Delete winget's own diagnostic log file(s) created during this run (winget has no native flag to suppress log creation, so this deletes them afterward instead)
#     -SaveResults <PATH>: Append results to a text file (i.e. -SaveResults "C:\output.txt")
#     -UpgradeAll: Upgrade all available packages after displaying the upgrade list
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$InstallIfMissing,
	[switch]$LogToDesktop,
	[switch]$NoConsoleOutput,
	[switch]$NoLog,
	[string]$SaveResults,
	[switch]$UpgradeAll,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-InstallIfMissing] [-LogToDesktop] [-NoConsoleOutput] [-NoLog] [-SaveResults <PATH>] [-UpgradeAll] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -InstallIfMissing    Install winget if it is not found on the system" -ForegroundColor Cyan
	Write-Host "  -LogToDesktop        Save results to a file named winget_<COMPUTERNAME>.txt on the desktop" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -SaveResults); errors go to the results file instead" -ForegroundColor Cyan
	Write-Host "  -NoLog               Delete winget's own diagnostic log file(s) created during this run" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Append results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
	Write-Host "  -UpgradeAll          Upgrade all available packages after displaying the upgrade list" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# Validate -SaveResults path if specified
if ($SaveResults) {
	$saveDir = Split-Path $SaveResults -Parent
	if ($saveDir -and -not (Test-Path $saveDir)) {
		Write-Host ""
		Write-Error "The directory for -SaveResults does not exist: '$saveDir'"
		exit 1
	}
}

# Write the hostname as a header line the first time this file is created, so a fleet of per-machine files can be identified at a glance
if ($SaveResults -and -not (Test-Path $SaveResults)) {
	try {
		[System.IO.File]::AppendAllText($SaveResults, "$env:COMPUTERNAME`:`n")
	}
	catch {
		Write-Host ""
		Write-Warning "Could not write hostname header to '$SaveResults': $($_.Exception.Message)"
	}
}

# -NoConsoleOutput requires -SaveResults
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults."
	exit 1
}

# Optional log file path for -LogToDesktop
if ($LogToDesktop) {
	$desktopPath = [Environment]::GetFolderPath("Desktop")
	$logFile = Join-Path $desktopPath "winget_$($env:COMPUTERNAME).txt"
}

# Snapshot winget's own diagnostic log directory before running so -NoLog can identify and remove only the log file(s) created during this run, without touching any pre-existing logs
if ($NoLog) {
	$wingetLogDir = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"
	$preExistingLogs = if (Test-Path $wingetLogDir) { (Get-ChildItem -Path $wingetLogDir -File -ErrorAction SilentlyContinue).Name } else { @() }
}

try {
	# Ensure winget is installed
	if (-not $NoConsoleOutput) { Write-Host "`nChecking for winget..." -ForegroundColor Cyan }
	if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
		if ($InstallIfMissing) {
			if (-not $NoConsoleOutput) { Write-Host "winget not found. Attempting installation..." -ForegroundColor Cyan }
			Add-AppxPackage -RegisterByFamilyName "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"
			Start-Sleep -Seconds 3
			if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
				throw "winget installation failed."
			}
			if (-not $NoConsoleOutput) { Write-Host "winget installed successfully." -ForegroundColor Green }
		}
		else {
			throw "winget is not installed. Use -InstallIfMissing to install it."
		}
	}
	else {
		if (-not $NoConsoleOutput) { Write-Host "winget is already installed." -ForegroundColor Green }
	}

	# Priming step for first-run initialization
	if (-not $NoConsoleOutput) { Write-Host "`nPriming winget (first-run initialization)..." -ForegroundColor Cyan }
	winget source update --disable-interactivity
	winget upgrade --accept-source-agreements --disable-interactivity >$null 2>&1

	# Collect pinned apps
	$pinnedApps = @()
	$pinnedAppsRaw = winget pin list 2>$null
	if ($pinnedAppsRaw) {
		$pinnedApps = $pinnedAppsRaw | Select-Object -Skip 1 | ForEach-Object {
			if ($_ -match '^\S') { ($_ -split '\s{2,}')[1] }
		} | Where-Object { $_ }
	}

	# Pre-check upgrades using winget native table
	if (-not $NoConsoleOutput) { Write-Host "`nChecking for available upgrades..." -ForegroundColor Cyan }

	# Capture all upgradeable packages, filtering pinned apps for logging purposes
	$allUpgrades = winget upgrade --accept-source-agreements --disable-interactivity
	if ($LASTEXITCODE -ne 0) {
		throw "winget exited with code $LASTEXITCODE while checking for upgrades."
	}
	$upgradeable = $allUpgrades | Where-Object {
		$appId = ($_ -split '\s{2,}')[1]
		# Require the ID column to look like a real winget package ID (i.e. Publisher.Package), which excludes the header row, separator line, and summary line ("N upgrades available.")
		$appId -match '^\S+\.\S+' -and -not $pinnedApps.Contains($appId)
	}

	# Display native table to console
	if (-not $NoConsoleOutput) { $allUpgrades }

	# Upgrade all if requested
	if ($UpgradeAll -and $upgradeable) {
		if (-not $NoConsoleOutput) { Write-Host "`nUpgrading all available packages..." -ForegroundColor Cyan }
		winget upgrade --all --accept-source-agreements --accept-package-agreements --disable-interactivity
		if ($LASTEXITCODE -ne 0) {
			throw "winget exited with code $LASTEXITCODE while upgrading packages."
		}
		if (-not $NoConsoleOutput) { Write-Host "`nUpgrade operation completed." -ForegroundColor Green }
	}

	# Save to desktop log if requested
	if ($LogToDesktop) {
		if ($upgradeable) {
			$logLines = @($env:COMPUTERNAME) + $upgradeable
		}
		else {
			$logLines = @(
				$env:COMPUTERNAME
				"No upgradeable apps found (excluding pinned)."
			)
		}
		$logLines | Out-File -FilePath $logFile -Encoding UTF8
		if (-not $NoConsoleOutput) { Write-Host "`nwinget log saved to $logFile." -ForegroundColor Green }
	}

	# Append to -SaveResults file if requested
	if ($SaveResults) {
		$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		$appendLines = @()
		$appendLines += "=== $($env:COMPUTERNAME) ($timestamp) ==="

		if ($upgradeable) {
			$appendLines += $upgradeable
		}
		else {
			$appendLines += "No upgradeable apps found (excluding pinned)."
		}

		$appendLines += ""

		try {
			$appendString = ($appendLines -join "`n")
			[System.IO.File]::AppendAllText($SaveResults, $appendString)
			if (-not $NoConsoleOutput) { Write-Host "`nResults appended to text file: $SaveResults" -ForegroundColor Green }
		}
		catch {
			# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
			Write-Host ""
			Write-Warning "Could not append results to '$SaveResults': $($_.Exception.Message)"
		}
	}

	if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Completed successfully." -ForegroundColor Green }
	exit 0
}
catch {
	$errorMessage = "$ScriptName`: An error occurred: $($_.Exception.Message)"
	if ($NoConsoleOutput) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$errorMessage`n")
		}
		catch {
			# The results file itself couldn't be written to, so there's nowhere else to record this - fall back to console as a last resort rather than losing it entirely
			Write-Host ""
			Write-Error $errorMessage
		}
	}
	else {
		Write-Host ""
		Write-Error $errorMessage
	}
	exit 1
}
finally {
	if ($NoLog -and (Test-Path $wingetLogDir)) {
		$newLogs = Get-ChildItem -Path $wingetLogDir -File -ErrorAction SilentlyContinue | Where-Object { $preExistingLogs -notcontains $_.Name }
		if ($newLogs) {
			$newLogs | Remove-Item -Force -ErrorAction SilentlyContinue
		}
	}
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.