# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script stops and disables the DiagTrack service (otherwise known as "Connected User Experiences and Telemetry")

#Requires -RunAsAdministrator

$serviceName = "DiagTrack"

# Stop the service
try {
	Stop-Service -Name $serviceName -Force -ErrorAction Stop
	Write-Host "Service '$serviceName' stopped successfully." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Could not stop service '$serviceName': $($_.Exception.Message)"
}

# Disable the service startup type
try {
	Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
	Write-Host "Service '$serviceName' startup type set to Disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Could not set startup type for service '$serviceName': $($_.Exception.Message)"
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.