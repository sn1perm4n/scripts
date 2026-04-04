# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script uses the Windows Update API to check for non-hidden Windows Updates, Microsoft Updates, and Microsoft Defender definition updates. It also attempts to update the "Last checked" timestamp in the Windows Update GUI (and ignore and optionally install updates based on user-input).

# IMPORTANT: This script enables "Receive updates for other Microsoft products" by default. To disable this behavior, comment out the six lines below the "Enable Microsoft Update" comment in the script. For best security, it is recommended to leave this enabled.

# NOTE: The GUI "Last checked" timestamp may not update due to Windows Update orchestration behavior

# NOTE2: Cumulative and feature updates delivered via the UUP pipeline (i.e. monthly security rollups) may not be detected by this script due to a Windows Update COM API limitation. Always verify via the Windows Update GUI or Settings > Windows Update to ensure all critical updates are installed.

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
	Write-Host ""  # extra newline for readability
	exit 0
}

try {
	Write-Host "`nChecking for available Windows/Microsoft/Defender updates..." -ForegroundColor Cyan

	# Trigger a Windows Update scan so the GUI "Last checked" timestamp updates
	Start-Process -FilePath "UsoClient.exe" -ArgumentList "StartScan" -NoNewWindow -Wait

	# Enable Microsoft Update (equivalent to "Receive updates for other Microsoft products"). I STRONGLY recommend "Receive updates for other Microsoft products" be enabled in Windows Update -> Advanced options from a security standpoint. If you want it disabled, comment out the below six lines:
	$serviceManager = New-Object -ComObject Microsoft.Update.ServiceManager
	$serviceManager.AddService2(
		"7971f918-a847-4430-9279-4a52d1efe18d",
		7,
		""
	) | Out-Null

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
			-not ($_.Categories | Where-Object { $_.Name -eq 'Drivers' })
		}
	)

	if ($visibleUpdates.Count -eq 0) {
		Write-Host "`nNo updates available." -ForegroundColor Green
		Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
		$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		return
	}

	# Print available updates
	Write-Host "`nAvailable Windows/Microsoft/Defender Updates:" -ForegroundColor Yellow
	$visibleUpdates | ForEach-Object {
		Write-Host "- $($_.Title)"
	}

	# Exit here if -CheckOnly is specified
	if ($CheckOnly) {
		Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
		$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		return
	}

	# Prompt user unless -InstallAll is specified
	if ($InstallAll) {
		$response = 'Y'
	}
	else {
		do {
			$response = Read-Host "`nInstall these updates now? (Y/N)"
		} until ($response -match '^[YyNn]$')
	}

	if ($response -match '^[Yy]$') {
		Write-Host "`nInstalling Windows/Microsoft/Defender updates..." -ForegroundColor Cyan

		$updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
		foreach ($update in $visibleUpdates) {
			$updatesToInstall.Add($update) | Out-Null
		}

		$installer = $updateSession.CreateUpdateInstaller()
		$installer.Updates = $updatesToInstall

		# AutoReboot is not supported on all systems, so wrap in try/catch
		try {
			$installer.AutoReboot = $false
		}
		catch {
			Write-Verbose "AutoReboot property not supported on this system, continuing without it."
		}

		$installResult = $installer.Install()

		if ($installResult.ResultCode -eq 2) {
			Write-Host "`nUpdates successfully installed." -ForegroundColor Green
		}
		else {
			# If result code 4, attempt to update Defender definitions via MpCmdRun.exe as a fallback
			if ($installResult.ResultCode -eq 4) {
				Write-Host "`nInstallation failed (result code 4). Attempting Defender definition update via MpCmdRun.exe..." -ForegroundColor Yellow
				try {
					& "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -SignatureUpdate
					Write-Host "`nDefender definition update completed via MpCmdRun.exe." -ForegroundColor Green
				}
				catch {
					Write-Warning "Defender definition update via MpCmdRun.exe also failed: $($_.Exception.Message)"
				}
			}
			else {
				Write-Warning "Update installation completed with result code: $($installResult.ResultCode)"
			}
		}

		if ($installResult.RebootRequired) {
			Write-Host "`nA system reboot is required to complete installation." -ForegroundColor Yellow
		}
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