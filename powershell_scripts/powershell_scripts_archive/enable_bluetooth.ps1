# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script enables Bluetooth

#Requires -RunAsAdministrator

try {
	Write-Host "`nChecking Bluetooth status..." -ForegroundColor Cyan

	$devices = Get-PnpDevice -Class Bluetooth -ErrorAction Stop

	if (-not $devices) {
		Write-Host "`nNo Bluetooth devices found." -ForegroundColor Yellow
		exit 0
	}

	$disabledDevices = $devices | Where-Object { $_.Status -eq 'Unknown' }

	if (-not $disabledDevices) {
		Write-Host "`nBluetooth already enabled." -ForegroundColor Yellow
		exit 0
	}

	$disabledDevices | Enable-PnpDevice -Confirm:$false -ErrorAction Stop
	Write-Host "`nBluetooth enabled successfully." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Error "An error occurred while enabling Bluetooth: $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.