# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script removes Microsoft Start Experiences App

#Requires -RunAsAdministrator

Write-Host "`nChecking for Microsoft Start Experiences App..." -ForegroundColor Cyan

if (-not (Get-AppxPackage -Name Microsoft.StartExperiencesApp)) {
	Write-Host "`nMicrosoft Start Experiences App is not installed. Nothing to remove." -ForegroundColor Yellow
	exit 0
}

try {
	Get-AppxPackage -Name Microsoft.StartExperiencesApp |
		Remove-AppxPackage -ErrorAction Stop
	Write-Host "`nMicrosoft Start Experiences App successfully uninstalled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Failed to uninstall Microsoft Start Experiences App: $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.