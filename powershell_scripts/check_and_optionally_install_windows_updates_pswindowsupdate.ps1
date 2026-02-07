# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script uses the PSWindowsUpdate module to check for non-hidden Windows Updates, Microsoft Updates, Microsoft Defender definition updates, and attempts to update the "Last checked" timestamp in the Windows Update GUI (and ignore and optionally install updates based on user-input)
# NOTE: The GUI "Last checked" timestamp may not update due to Windows Update orchestration behavior
# NOTE2: These scripts respect the user's "Receive updates for other Microsoft products" setting in Advanced Options. For best security, it is recommended to enable this setting in Windows Update -> Advanced Options.
#Requires -RunAsAdministrator

# Ensure script runs as Administrator
$principal = New-Object Security.Principal.WindowsPrincipal `
	([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $principal.IsInRole(
	[Security.Principal.WindowsBuiltInRole]::Administrator
)) {
	Write-Host "Please run this script as Administrator. Press any key to exit..." -ForegroundColor Red
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit 1
}

# Check for/install third-party PSWindowsUpdate module, check for Windows Updates, print available updates to the console (also ignores hidden updates), and install them based on user-input
try {
	Write-Host "Checking for PSWindowsUpdate module..." -ForegroundColor Cyan

	if (-not (Get-Module -ListAvailable -Name 'PSWindowsUpdate')) {
		Write-Host "PSWindowsUpdate module not found. Installing..." -ForegroundColor Yellow

		Install-Module PSWindowsUpdate -Repository PSGallery -Force -ErrorAction Stop
		Write-Host "PSWindowsUpdate module installed successfully." -ForegroundColor Green
	} else {
		Write-Host "PSWindowsUpdate module already installed." -ForegroundColor Green
	}

	Import-Module PSWindowsUpdate -ErrorAction Stop

	Write-Host "Checking for available Windows/Microsoft/Defender updates..." -ForegroundColor Cyan

	# Trigger a Windows Update scan so the GUI "Last checked" timestamp updates
	Start-Process -FilePath "UsoClient.exe" -ArgumentList "StartScan" -NoNewWindow -Wait

	# Get all updates, ignore hidden, include Software and Definition updates, skip drivers
	$updates = Get-WindowsUpdate -MicrosoftUpdate -IgnoreUserInput -ErrorAction Stop |
		Where-Object { -not $_.IsHidden -and ($_.Type -eq 'Software' -or $_.Type -eq 'Definition') }

	if ($visibleUpdates.Count -eq 0) {
		Write-Host "`nNo updates available." -ForegroundColor Green
		Write-Host "Press any key to exit..." -ForegroundColor Cyan
		$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		return
	}

	# Print available updates
	Write-Host "`nAvailable Windows/Microsoft/Defender Updates:" -ForegroundColor Yellow
	$updates | ForEach-Object {
		Write-Host "- $($_.Title)"
	}

	# Prompt user for installation choice
	do {
		$choice = Read-Host "`nInstall these updates now? (Y/N)"
	} until ($choice -match '^[YyNn]$')

	if ($choice -match '^[Yy]$') {
		Write-Host "`nInstalling Windows/Microsoft/Defender updates..." -ForegroundColor Cyan

		Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -IgnoreUserInput -AutoReboot:$false -ErrorAction Stop |
			Out-Null

		Write-Host "Updates successfully installed." -ForegroundColor Green
	} else {
		Write-Host "Updates were not installed because the user declined installation." -ForegroundColor Yellow
	}

} catch {
	Write-Warning "An error occurred while checking or installing updates: $($_.Exception.Message)."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.