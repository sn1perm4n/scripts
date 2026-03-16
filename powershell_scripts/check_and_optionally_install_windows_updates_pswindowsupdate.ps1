# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script uses the PSWindowsUpdate module to check for non-hidden Windows Updates, Microsoft Updates, and Microsoft Defender definition updates. It also attempts to update the "Last checked" timestamp in the Windows Update GUI (and ignore and optionally install updates based on user-input).

# IMPORTANT: These scripts respect the user's "Receive updates for other Microsoft products" setting in Advanced Options. For best security, it is recommended to enable this setting in Windows Update -> Advanced Options.

# NOTE: The GUI "Last checked" timestamp may not update due to Windows Update orchestration behavior

# NOTE2: Some updates may appear listed even if hidden via the Windows Update GUI (i.e. KB5007651); these are safe to ignore. Microsoft Defender definitions may also show as "available" even if the latest version is installed. PSWindowsUpdate relies on the Windows Update Agent cache, which can lag behind the true installed state. Verify the installed version with Get-MpComputerStatus.

#Requires -RunAsAdministrator

# Check for/install third-party PSWindowsUpdate module, check for Windows Updates, print available updates to the console (also ignores hidden updates), and install them based on user-input
try {
	Write-Host "`nChecking for PSWindowsUpdate module..." -ForegroundColor Cyan

	if (-not (Get-Module -ListAvailable -Name 'PSWindowsUpdate')) {
		Write-Host "PSWindowsUpdate module not found. Installing..." -ForegroundColor Yellow
		Install-Module PSWindowsUpdate -Repository PSGallery -Force -ErrorAction Stop
		Write-Host "PSWindowsUpdate module installed successfully." -ForegroundColor Green
	} else {
		Write-Host "PSWindowsUpdate module already installed." -ForegroundColor Green
	}

	Import-Module PSWindowsUpdate -ErrorAction Stop

	Write-Host "`nChecking for available Windows/Microsoft/Defender updates..." -ForegroundColor Cyan

	# Trigger Windows Update scan so "Last checked" GUI timestamp updates
	Start-Process -FilePath "UsoClient.exe" -ArgumentList "StartScan" -NoNewWindow -Wait

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
		Write-Host "Press any key to exit..."
		$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		return
	}

	# Print all available updates
	Write-Host "`nAvailable Windows/Microsoft/Defender Updates:" -ForegroundColor Yellow
	$updates | ForEach-Object {
		Write-Host "- $($_.Title)"
	}

	# Prompt user for installation
	do {
		$choice = Read-Host "`nInstall these updates now? (Y/N)"
	} until ($choice -match '^[YyNn]$')

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

		Write-Host "Updates successfully installed." -ForegroundColor Green
	} else {
		Write-Host "Updates were not installed because the user declined installation." -ForegroundColor Yellow
	}

} catch {
	Write-Warning "An error occurred while checking or installing updates: $($_.Exception.Message)."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.