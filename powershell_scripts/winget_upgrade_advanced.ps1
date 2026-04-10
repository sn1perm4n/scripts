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
#     -SaveResults <PATH>: Append results to a text file (i.e. -SaveResults "C:\output.txt")
#     -UpgradeAll: Upgrade all available packages after displaying the upgrade list
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$InstallIfMissing,
	[switch]$LogToDesktop,
	[string]$SaveResults,
	[switch]$UpgradeAll,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-InstallIfMissing] [-LogToDesktop] [-SaveResults <PATH>] [-UpgradeAll] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -InstallIfMissing    Install winget if it is not found on the system" -ForegroundColor Cyan
	Write-Host "  -LogToDesktop        Save results to a file named winget_<COMPUTERNAME>.txt on the desktop" -ForegroundColor Cyan
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

# Optional log file path for -LogToDesktop
if ($LogToDesktop) {
	$desktopPath = [Environment]::GetFolderPath("Desktop")
	$logFile = Join-Path $desktopPath "winget_$($env:COMPUTERNAME).txt"
}

try {
	# Ensure winget is installed
	Write-Host "`nChecking for winget..." -ForegroundColor Cyan
	if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
		if ($InstallIfMissing) {
			Write-Host "winget not found. Attempting installation..." -ForegroundColor Cyan
			Add-AppxPackage -RegisterByFamilyName "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"
			Start-Sleep -Seconds 3
			if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
				throw "winget installation failed."
			}
			Write-Host "winget installed successfully." -ForegroundColor Green
		}
		else {
			throw "winget is not installed. Use -InstallIfMissing to install it."
		}
	}
	else {
		Write-Host "winget is already installed." -ForegroundColor Green
	}

	# Priming step for first-run initialization
	Write-Host "`nPriming winget (first-run initialization)..." -ForegroundColor Cyan
	winget source update
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
	Write-Host "`nChecking for available upgrades..." -ForegroundColor Cyan

	# Capture all upgradeable packages, filtering pinned apps for logging purposes
	$allUpgrades = winget upgrade --accept-source-agreements --disable-interactivity | Tee-Object -Variable rawOutput
	$upgradeable = $allUpgrades | Where-Object {
		$appId = ($_ -split '\s{2,}')[1]
		-not $pinnedApps.Contains($appId)
	}

	# Display native table to console
	$allUpgrades

	# Upgrade all if requested
	if ($UpgradeAll -and $upgradeable) {
		Write-Host "`nUpgrading all available packages..." -ForegroundColor Cyan
		winget upgrade --all --accept-source-agreements --accept-package-agreements --disable-interactivity
		Write-Host "`nUpgrade operation completed." -ForegroundColor Green
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
		Write-Host "`nwinget log saved to $logFile." -ForegroundColor Green
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
			Write-Host "`nResults appended to text file: $SaveResults" -ForegroundColor Green
		}
		catch {
			Write-Host ""
			Write-Warning "Could not append results to '$SaveResults': $($_.Exception.Message)"
		}
	}

	Write-Host "`nCompleted successfully." -ForegroundColor Green
	exit 0
}
catch {
	Write-Host ""
	Write-Warning "An error occurred: $($_.Exception.Message)"
	exit 1
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.