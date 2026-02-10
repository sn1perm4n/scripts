# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script uses the Windows Update API to check for non-hidden Windows Updates, Microsoft Updates, and Microsoft Defender definition updates. It also attempts to update the "Last checked" timestamp in the Windows Update GUI (and ignore and optionally install updates based on user-input).

# IMPORTANT: These scripts respect the user's "Receive updates for other Microsoft products" setting in Advanced Options. For best security, it is recommended to enable this setting in Windows Update -> Advanced Options.

# NOTE: The GUI "Last checked" timestamp may not update due to Windows Update orchestration behavior
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

try {
	Write-Host "Checking for available Windows/Microsoft/Defender updates..." -ForegroundColor Cyan

	# Trigger a Windows Update scan so the GUI "Last checked" timestamp updates
	Start-Process -FilePath "UsoClient.exe" -ArgumentList "StartScan" -NoNewWindow -Wait

	# Enable Microsoft Update (equivalent to "Receive updates for other Microsoft products"). I STRONGLY recommend "Receive updates for other Microsoft products" be enabled in Windows Update -> Advanced options from a security standpoint. If you enable it, uncomment the below six lines:
#	$serviceManager = New-Object -ComObject Microsoft.Update.ServiceManager
#	$serviceManager.AddService2(
#		"7971f918-a847-4430-9279-4a52d1efe18d",
#		7,
#		""
#	) | Out-Null

	# Create a Windows Update session
	$updateSession  = New-Object -ComObject Microsoft.Update.Session
	$updateSearcher = $updateSession.CreateUpdateSearcher()

	# Search for all available updates
	$searchResult = $updateSearcher.Search("IsInstalled=0")

	# Ignore hidden updates and drivers; include Software and Definition updates
	$visibleUpdates = @(
		$searchResult.Updates |
		Where-Object {
			-not $_.IsHidden -and
			($_.Type -eq 'Software' -or $_.Type -eq 'Definition')
		}
	)

	if ($visibleUpdates.Count -eq 0) {
		Write-Host "`nNo updates available." -ForegroundColor Green
		Write-Host "Press any key to exit..." -ForegroundColor Cyan
		$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		return
	}

	# Print available updates
	Write-Host "`nAvailable Windows/Microsoft/Defender Updates:" -ForegroundColor Yellow
	$visibleUpdates | ForEach-Object {
		Write-Host "- $($_.Title)"
	}

	# Prompt user only because updates exist
	do {
		$response = Read-Host "`nInstall these updates now? (Y/N)"
	} until ($response -match '^[YyNn]$')

	if ($response -match '^[Yy]$') {
		Write-Host "`nInstalling Windows/Microsoft/Defender updates..." -ForegroundColor Cyan

		$updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
		foreach ($update in $visibleUpdates) {
			$updatesToInstall.Add($update) | Out-Null
		}

		$installer = $updateSession.CreateUpdateInstaller()
		$installer.Updates = $updatesToInstall
		$installer.AutoReboot = $false

		$installResult = $installer.Install()

		if ($installResult.ResultCode -eq 2) {
			Write-Host "Updates successfully installed." -ForegroundColor Green
		} else {
			Write-Warning "Update installation completed with result code: $($installResult.ResultCode)."
		}

		if ($installResult.RebootRequired) {
			Write-Warning "A system reboot is required to complete installation."
		}

	} else {
		Write-Warning "Updates were not installed because the user declined installation."
	}

} catch {
	Write-Warning "An error occurred while checking or installing updates: $($_.Exception.Message)."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.