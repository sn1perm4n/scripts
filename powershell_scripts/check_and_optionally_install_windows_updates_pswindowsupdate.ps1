# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script uses the PSWindowsUpdate module to check for non-hidden Windows Updates, Microsoft Updates, and Microsoft Defender definition updates. It also attempts to update the "Last checked" timestamp in the Windows Update GUI (and ignore and optionally install updates based on user-input).

# IMPORTANT: This script enables "Receive updates for other Microsoft products" by default. To disable this behavior, comment out the six lines below the "Enable Microsoft Update" comment in the script. For best security, it is recommended to leave this enabled.

# NOTE: The GUI "Last checked" timestamp may not update due to Windows Update orchestration behavior

# NOTE2: Some updates may appear listed even if hidden via the Windows Update GUI (i.e. KB5007651); these are safe to ignore. Microsoft Defender definitions may also show as "available" even if the latest version is installed. PSWindowsUpdate relies on the Windows Update Agent cache, which can lag behind the true installed state. Verify the installed version with Get-MpComputerStatus.

# NOTE3: Cumulative and feature updates delivered via the UUP pipeline (e.g. monthly security rollups) may not be detected by this script due to a PSWindowsUpdate/Windows Update API limitation. Always verify via the Windows Update GUI or Settings > Windows Update to ensure all critical updates are installed.

# Optional flags:
#     -CheckOnly: Check for updates without prompting to install
#     -InstallAll: Automatically install all available updates without prompting
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding()]
param (
	[switch]$CheckOnly,
	[switch]$InstallAll,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-CheckOnly] [-InstallAll] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -CheckOnly   Check for updates without prompting to install" -ForegroundColor Cyan
	Write-Host "  -InstallAll  Automatically install all available updates without prompting" -ForegroundColor Cyan
	Write-Host "  -Help        Display this help message" -ForegroundColor Cyan
	Write-Host "" # extra newline for readability
	exit 0
}

# Check for/install third-party PSWindowsUpdate module, check for Windows Updates, print available updates to the console (also ignores hidden updates), and install them based on user-input
try {
	Write-Host "`nChecking for PSWindowsUpdate module..." -ForegroundColor Cyan

	if (-not (Get-Module -ListAvailable -Name 'PSWindowsUpdate')) {
		Write-Host "PSWindowsUpdate module not found. Installing..." -ForegroundColor Yellow
		Install-Module PSWindowsUpdate -Repository PSGallery -Force -ErrorAction Stop
		Write-Host "PSWindowsUpdate module installed successfully." -ForegroundColor Green
	}
	else {
		Write-Host "PSWindowsUpdate module already installed." -ForegroundColor Green
	}

	Import-Module PSWindowsUpdate -ErrorAction Stop

	Write-Host "`nChecking for available Windows/Microsoft/Defender updates..." -ForegroundColor Cyan

	# Trigger Windows Update scan so "Last checked" GUI timestamp updates
	Start-Process -FilePath "UsoClient.exe" -ArgumentList "StartScan" -NoNewWindow -Wait

	# Enable Microsoft Update (equivalent to "Receive updates for other Microsoft products"). If you want it disabled, comment out the below six lines:
	$serviceManager = New-Object -ComObject Microsoft.Update.ServiceManager
	$serviceManager.AddService2(
		"7971f918-a847-4430-9279-4a52d1efe18d",
		7,
		""
	) | Out-Null

	# Get Windows/Microsoft updates (ignore hidden, skip drivers)
	$windowsUpdates = Get-WindowsUpdate -MicrosoftUpdate -IgnoreUserInput -ErrorAction Stop |
		Where-Object { -not $_.IsHidden -and $_.UpdateType -ne 'Driver' }

	# Check Defender definition update
	$defenderStatus = Get-MpComputerStatus
	$defenderUpdateNeeded = $false

	if ($defenderStatus.AntivirusSignatureLastUpdated -lt (Get-Date).Date) {
		$defenderUpdateNeeded = $true
	}

	# Build unified updates list
	$updates = @()

	if ($windowsUpdates.Count -gt 0) {
		$updates += $windowsUpdates | ForEach-Object {
			[PSCustomObject]@{
				Title = $_.Title
				Type  = "Windows/Microsoft"
			}
		}
	}

	if ($defenderUpdateNeeded) {
		$updates += [PSCustomObject]@{
			Title = "Security Intelligence Update for Microsoft Defender Antivirus - Version $($defenderStatus.AntivirusSignatureVersion) - Current Channel (Broad)"
			Type  = "Defender"
		}
	}

	if ($updates.Count -eq 0) {
		Write-Host "`nNo updates available." -ForegroundColor Green
		Write-Host "`nPress any key to exit..."
		$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		return
	}

	# Print all available updates
	Write-Host "`nAvailable Windows/Microsoft/Defender Updates:" -ForegroundColor Yellow
	$updates | ForEach-Object {
		Write-Host "- $($_.Title)"
	}

	# Exit here if -CheckOnly is specified
	if ($CheckOnly) {
		Write-Host "`nPress any key to exit..."
		$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		return
	}

	# Prompt user unless -InstallAll is specified
	if ($InstallAll) {
		$choice = 'Y'
	}
	else {
		do {
			$choice = Read-Host "`nInstall these updates now? (Y/N)"
		} until ($choice -match '^[YyNn]$')
	}

	if ($choice -match '^[Yy]$') {
		Write-Host "`nInstalling updates..." -ForegroundColor Cyan

		# Install Windows/Microsoft updates
		if ($windowsUpdates.Count -gt 0) {
			Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -IgnoreUserInput -AutoReboot:$false -ErrorAction Stop | Out-Null
		}

		# Install Defender update
		if ($defenderUpdateNeeded) {
			Update-MpSignature -ErrorAction Stop
		}

		Write-Host "`nUpdates successfully installed." -ForegroundColor Green
	}
	else {
		Write-Host "`nUpdates were not installed." -ForegroundColor Yellow
	}
}
catch {
	Write-Warning "An error occurred while checking or installing updates: $($_.Exception.Message)"
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.