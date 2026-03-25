# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script removes Microsoft Edge Game Assist (sometimes reinstalls itself when Microsoft Edge updates)

#Requires -RunAsAdministrator

# Check for and remove Microsoft Edge Game Assist if installed
if (-not (Get-AppxPackage -Name Microsoft.Edge.GameAssist)) {
	Write-Host "Microsoft Edge Game Assist is not installed. Nothing to remove." -ForegroundColor Yellow
	return
}

try {
	Get-AppxPackage -Name Microsoft.Edge.GameAssist |
		Remove-AppxPackage -ErrorAction Stop

	Write-Host "Successfully uninstalled Microsoft Edge Game Assist." -ForegroundColor Green
}
catch {
	Write-Host "Failed to uninstall Microsoft Edge Game Assist: $($_.Exception.Message)." -ForegroundColor Red
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.