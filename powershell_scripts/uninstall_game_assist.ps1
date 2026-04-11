# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script removes Microsoft Edge Game Assist (sometimes reinstalls itself when Microsoft Edge updates)

#Requires -RunAsAdministrator

Write-Host "`nChecking for Microsoft Edge Game Assist..." -ForegroundColor Cyan

if (-not (Get-AppxPackage -Name Microsoft.Edge.GameAssist)) {
	Write-Host "`nMicrosoft Edge Game Assist is not installed. Nothing to remove." -ForegroundColor Yellow
	exit 0
}

try {
	Get-AppxPackage -Name Microsoft.Edge.GameAssist |
		Remove-AppxPackage -ErrorAction Stop
	Write-Host "`nMicrosoft Edge Game Assist successfully uninstalled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Error "Failed to uninstall Microsoft Edge Game Assist: $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.