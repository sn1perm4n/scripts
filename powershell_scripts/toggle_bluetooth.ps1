# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script enables or disables Bluetooth

# Optional flags:
#     -Disable:   Disable Bluetooth without prompting
#     -Enable:    Enable Bluetooth without prompting
#     -Preview:   Report current Bluetooth device status without changing anything
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Disable,
	[switch]$Enable,
	[switch]$Preview,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Disable] [-Enable] [-Preview] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Disable  Disable Bluetooth without prompting" -ForegroundColor Cyan
	Write-Host "  -Enable   Enable Bluetooth without prompting" -ForegroundColor Cyan
	Write-Host "  -Preview  Report current Bluetooth device status without changing anything" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# -Enable and -Disable are mutually exclusive
if ($Enable -and $Disable) {
	Write-Host ""
	Write-Error "-Enable and -Disable are mutually exclusive."
	exit 1
}

# -Preview reports current status and bypasses the interactive menu entirely
if ($Preview) {
	try {
		$devices = Get-PnpDevice -Class Bluetooth -ErrorAction Stop

		if (-not $devices) {
			Write-Host ""
			Write-Warning "No Bluetooth devices found."
			exit 0
		}

		foreach ($device in $devices) {
			$state = if ($device.Status -eq 'OK') { "ENABLED" } elseif ($device.Status -eq 'Error') { "DISABLED" } else { "STATUS: $($device.Status)" }
			Write-Host "$($device.FriendlyName): $state"
		}
	}
	catch {
		Write-Host ""
		Write-Error "$ScriptName`: An error occurred while checking Bluetooth status: $($_.Exception.Message)"
		exit 1
	}

	exit 0
}

# If neither flag is passed, fall through to interactive menu
if (-not $Enable -and -not $Disable) {
	Write-Host "`n1. Enable Bluetooth"
	Write-Host "2. Disable Bluetooth"
	Write-Host "`nPress 1 or 2 to continue..." -ForegroundColor Cyan

	while ($true) {
		$key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
		if ($key -eq '1' -or $key -eq '2') { break }
		Write-Host ""
		Write-Warning "Invalid input. Please press 1 or 2..."
	}

	$Enable = $key -eq '1'
	$Disable = $key -eq '2'
}

$enabling = $Enable -eq $true

try {
	Write-Host "`nChecking Bluetooth status..." -ForegroundColor Cyan
	$devices = Get-PnpDevice -Class Bluetooth -ErrorAction Stop

	if (-not $devices) {
		Write-Host ""
		Write-Warning "No Bluetooth devices found."
		exit 0
	}

	if ($enabling) {
		$targetDevices = $devices | Where-Object { $_.Status -eq 'Error' }
		if (-not $targetDevices) {
			Write-Host ""
			Write-Warning "Bluetooth is already enabled."
			exit 0
		}
		$targetDevices | Enable-PnpDevice -Confirm:$false -ErrorAction Stop
		Write-Host "`n$ScriptName`: Bluetooth enabled successfully." -ForegroundColor Green
	}
	else {
		$targetDevices = $devices | Where-Object { $_.Status -eq 'OK' }
		if (-not $targetDevices) {
			Write-Host ""
			Write-Warning "Bluetooth is already disabled."
			exit 0
		}
		$targetDevices | Disable-PnpDevice -Confirm:$false -ErrorAction Stop
		Write-Host "`n$ScriptName`: Bluetooth disabled successfully." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	if ($enabling) {
		Write-Error "$ScriptName`: An error occurred while enabling Bluetooth: $($_.Exception.Message)"
	}
	else {
		Write-Error "$ScriptName`: An error occurred while disabling Bluetooth: $($_.Exception.Message)"
	}
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.