# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables Wi-Fi. The name of your Wi-Fi adapter may differ so confirm first with the following PowerShell command (if you don't do this you'll see a bunch of red errors):
# Get-NetAdapter

#Requires -RunAsAdministrator

try {
	Write-Host "`nChecking Wi-Fi status..." -ForegroundColor Cyan

	$adapter = Get-NetAdapter -Name "Wi-Fi" -ErrorAction Stop

	if ($adapter.Status -eq 'Disabled') {
		Write-Host "`nWi-Fi is already disabled." -ForegroundColor Yellow
		exit 0
	}

	Disable-NetAdapter -Name "Wi-Fi" -Confirm:$false -ErrorAction Stop
	Write-Host "`nWi-Fi disabled successfully." -ForegroundColor Green
}
catch {
	Write-Error "An error occurred while disabling Wi-Fi: $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.