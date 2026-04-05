# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables Bluetooth

#Requires -RunAsAdministrator

try {
	$devices = Get-PnpDevice -Class Bluetooth -ErrorAction Stop

	if (-not $devices) {
		Write-Host "`nNo Bluetooth devices found." -ForegroundColor Yellow
		exit 0
	}

	$enabledDevices = $devices | Where-Object { $_.Status -eq 'OK' }

	if (-not $enabledDevices) {
		Write-Host "`nBluetooth already disabled." -ForegroundColor Yellow
		exit 0
	}

	$enabledDevices | Disable-PnpDevice -Confirm:$false -ErrorAction Stop
	Write-Host "`nBluetooth disabled successfully." -ForegroundColor Green
}
catch {
	Write-Error "An error occurred while disabling Bluetooth: $($_.Exception.Message)"
	exit 1
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.