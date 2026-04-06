# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script updates the winget source database and then runs the winget upgrade command so potential updates can be seen
# Individual packages can then be upgraded via their ID, i.e.: "winget upgrade Microsoft.VCRedist.2013.x86"
# If you want to upgrade everything, you can run "winget upgrade --all"
# Available commands: https://learn.microsoft.com/en-us/windows/package-manager/winget/upgrade
# winget pin add --id <APP_ID> - Disables version checking for said app (useful if you need to avoid upgrading specific applications)
# winget pin remove --id <APP_ID> - Removes a pinned app from winget
# winget pin list - Shows the current pinned app list

# NOTE: On a fresh system where winget has never been run, this script may appear to hang until the priming step completes. This ensures first-run agreements are accepted non-interactively using v1.28.220 flags.

#Requires -RunAsAdministrator

param (
	[switch]$InstallIfMissing,
	[switch]$LogToDesktop,
	[switch]$UpgradeAll
)

$ErrorActionPreference = "Stop"

# Optional log file path
if ($LogToDesktop) {
	$desktopPath = [Environment]::GetFolderPath("Desktop")
	$logFile = Join-Path $desktopPath "winget_$($env:COMPUTERNAME).txt"
}

# Temporary files for Start-Process output
$tempOut = Join-Path $env:TEMP "winget_temp_$PID.txt"
$tempErr = Join-Path $env:TEMP "winget_temp_err_$PID.txt"

try {
	# Ensure winget is installed
	Write-Host "Checking for winget..." -ForegroundColor Cyan
	if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
		if ($InstallIfMissing) {
			Write-Host "winget not found. Attempting installation..." -ForegroundColor Cyan
			Add-AppxPackage -RegisterByFamilyName "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"
			Start-Sleep -Seconds 3
			if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
				throw "winget installation failed."
			}
			Write-Host "winget installed successfully." -ForegroundColor Green
		} else {
			throw "winget is not installed. Use -InstallIfMissing to install it."
		}
	} else {
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
		$pinnedApps = $pinnedAppsRaw | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] }
	}

	# Pre-check upgrades using winget native table
	Write-Host "`nChecking for available upgrades..." -ForegroundColor Cyan

	# Capture all upgradeable packages, but filter pinned apps for logging purposes
	$allUpgrades = winget upgrade --accept-source-agreements --disable-interactivity | Tee-Object -Variable rawOutput
	$upgradeable = $allUpgrades | Where-Object {
		$appId = ($_ -split '\s+')[0]
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

	# Prepare log file
	if ($LogToDesktop) {
		if ($upgradeable) {
			$logLines = @($env:COMPUTERNAME) + $upgradeable
		} else {
			$logLines = @(
				$env:COMPUTERNAME
				"No upgradeable apps found (excluding pinned)."
			)
		}

		$logLines | Out-File -FilePath $logFile -Encoding UTF8
		Write-Host "`nwinget log saved to $logFile." -ForegroundColor Green
	}

	# Read-Host # Uncomment when testing to prevent window from closing

	Write-Host "`nCompleted successfully." -ForegroundColor Green
	exit 0

} catch {
	Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
	exit 1
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.
