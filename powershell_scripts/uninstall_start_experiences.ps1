# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script removes Microsoft Start Experiences App

#Requires -RunAsAdministrator

# Check for and remove Start Experiences App if installed
if (-not (Get-AppxPackage -Name Microsoft.StartExperiencesApp)) {
	Write-Host "Start Experiences App is not installed. Nothing to remove." -ForegroundColor Yellow
	return
}

try {
	Get-AppxPackage -Name Microsoft.StartExperiencesApp |
		Remove-AppxPackage -ErrorAction Stop

	Write-Host "Successfully uninstalled Start Experiences App." -ForegroundColor Green
}
catch {
	Write-Host "Failed to uninstall Start Experiences App: $($_.Exception.Message)." -ForegroundColor Red
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.