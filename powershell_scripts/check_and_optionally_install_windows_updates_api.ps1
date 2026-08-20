# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script uses the Windows Update API to check for non-hidden Windows Updates, Microsoft Updates, and Microsoft Defender definition updates. It also attempts to update the "Last checked" timestamp in the Windows Update GUI (and ignore and optionally install updates based on user-input).

# IMPORTANT: This script enables "Receive updates for other Microsoft products" by default. To disable this behavior, comment out the six lines below the "Enable Microsoft Update" comment in the script. For best security, it is recommended to leave this enabled.

# NOTE: The GUI "Last checked" timestamp may not update due to Windows Update orchestration behavior

# NOTE2: Cumulative and feature updates delivered via the UUP pipeline (i.e. monthly security rollups) may not be detected by this script due to a Windows Update COM API limitation. Always verify via the Windows Update GUI or Settings > Windows Update to ensure all critical updates are installed.

# Optional flags:
#     -CheckOnly:          Check for updates without prompting to install (mutually exclusive with -InstallAll)
#     -InstallAll:         Automatically install all available updates without prompting (mutually exclusive with -CheckOnly)
#     -NoConsoleOutput:    Suppress console output (requires -CheckOnly or -InstallAll, and -SaveResults)
#     -Reboot:             Automatically reboot after installing updates if required (default: no reboot)
#     -SaveResults <PATH>: Save results to a text file (appends if file exists)
#     -Help / -?:          Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$CheckOnly,
	[switch]$InstallAll,
	[switch]$NoConsoleOutput,
	[switch]$Reboot,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-CheckOnly] [-InstallAll] [-NoConsoleOutput] [-Reboot] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -CheckOnly           Check for updates without prompting to install (mutually exclusive with -InstallAll)" -ForegroundColor Cyan
	Write-Host "  -InstallAll          Automatically install all available updates without prompting (mutually exclusive with -CheckOnly)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -CheckOnly or -InstallAll, and -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Reboot              Automatically reboot after installing updates if required (default: no reboot)" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (appends if file exists)" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# -CheckOnly and -InstallAll are mutually exclusive
if ($CheckOnly -and $InstallAll) {
	Write-Host ""
	Write-Error "-CheckOnly and -InstallAll are mutually exclusive."
	exit 1
}

# -Reboot has no effect with -CheckOnly, since -CheckOnly never installs anything
if ($Reboot -and $CheckOnly) {
	Write-Host ""
	Write-Warning "-Reboot has no effect with -CheckOnly."
}

# -NoConsoleOutput requires -CheckOnly or -InstallAll, since without one of them the interactive install confirmation prompt would hang with no visible prompt
if ($NoConsoleOutput -and -not ($CheckOnly -or $InstallAll)) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -CheckOnly or -InstallAll."
	exit 1
}

# -NoConsoleOutput requires -SaveResults, since without it there's nowhere to record results
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults."
	exit 1
}

# Validate save path if specified
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

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

try {
	if (-not $NoConsoleOutput) { Write-Host "`nChecking for available Windows/Microsoft/Defender updates..." -ForegroundColor Cyan }

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
	$updateSession = New-Object -ComObject Microsoft.Update.Session
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
		$statusLine = "$ScriptName`: [$timestamp] [$env:COMPUTERNAME] No updates available."

		if (-not $NoConsoleOutput) {
			Write-Host "`nNo updates available." -ForegroundColor Green
			Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
			$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		}

		if ($SaveResults) {
			try {
				[System.IO.File]::AppendAllText($SaveResults, "$statusLine`n")
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

	# Print available updates
	if (-not $NoConsoleOutput) {
		Write-Host "`nAvailable Windows/Microsoft/Defender Updates:" -ForegroundColor Yellow
		$visibleUpdates | ForEach-Object {
			Write-Host "- $($_.Title)"
		}
	}

	$updateLines = $visibleUpdates | ForEach-Object { "- $($_.Title)" }

	# Exit here if -CheckOnly is specified
	if ($CheckOnly) {
		$statusLine = (@("$ScriptName`: [$timestamp] [$env:COMPUTERNAME] Available updates (not installed, -CheckOnly specified):") + $updateLines) -join "`n"

		if (-not $NoConsoleOutput) {
			Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
			$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		}

		if ($SaveResults) {
			try {
				[System.IO.File]::AppendAllText($SaveResults, "$statusLine`n")
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
		if (-not $NoConsoleOutput) { Write-Host "`nInstalling Windows/Microsoft/Defender updates..." -ForegroundColor Cyan }

		$updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
		foreach ($update in $visibleUpdates) {
			$updatesToInstall.Add($update) | Out-Null
		}

		$installer = $updateSession.CreateUpdateInstaller()
		$installer.Updates = $updatesToInstall

		# AutoReboot is not supported on all systems, so wrap in try/catch
		try {
			$installer.AutoReboot = $Reboot
		}
		catch {
			Write-Verbose "AutoReboot property not supported on this system, continuing without it."
		}

		$installResult = $installer.Install()

		if ($installResult.ResultCode -eq 2) {
			if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Updates successfully installed." -ForegroundColor Green }
			$installOutcomeNote = "Updates successfully installed."
		}
		else {
			# If result code 4, attempt to update Defender definitions via MpCmdRun.exe as a fallback
			if ($installResult.ResultCode -eq 4) {
				if (-not $NoConsoleOutput) { Write-Host "`nInstallation failed (result code 4). Attempting Defender definition update via MpCmdRun.exe..." -ForegroundColor Yellow }
				try {
					& "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -SignatureUpdate
					if (-not $NoConsoleOutput) { Write-Host "`nDefender definition update completed via MpCmdRun.exe." -ForegroundColor Green }
					$installOutcomeNote = "Installation failed (result code 4); Defender definition update completed via MpCmdRun.exe fallback."
				}
				catch {
					Write-Host ""
					Write-Warning "Defender definition update via MpCmdRun.exe also failed: $($_.Exception.Message)"
					$installOutcomeNote = "Installation failed (result code 4); Defender definition update via MpCmdRun.exe fallback also failed: $($_.Exception.Message)"
				}
			}
			else {
				if (-not $NoConsoleOutput) {
					Write-Host ""
					Write-Warning "Update installation completed with result code: $($installResult.ResultCode)"
				}
				$installOutcomeNote = "Update installation completed with result code: $($installResult.ResultCode)"
			}
		}

		if ($installResult.RebootRequired) {
			if (-not $NoConsoleOutput) { Write-Host "`nA system reboot is required to complete installation." -ForegroundColor Yellow }
			$installOutcomeNote += " A system reboot is required to complete installation."
		}

		$statusLine = (@("$ScriptName`: [$timestamp] [$env:COMPUTERNAME] $installOutcomeNote") + $updateLines) -join "`n"
	}
	else {
		if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Updates were not installed." -ForegroundColor Yellow }
		$statusLine = (@("$ScriptName`: [$timestamp] [$env:COMPUTERNAME] Updates available but not installed (declined):") + $updateLines) -join "`n"
	}

	if ($SaveResults) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$statusLine`n")
			if (-not $NoConsoleOutput) { Write-Host "`nResults saved to: $SaveResults" -ForegroundColor Green }
		}
		catch {
			# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}
}
catch {
	$errorMessage = "$ScriptName`: An error occurred while checking or installing updates: $($_.Exception.Message)"
	if ($NoConsoleOutput -and $SaveResults) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$errorMessage`n")
		}
		catch {
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

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.