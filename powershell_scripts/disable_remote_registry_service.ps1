# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables and stops the RemoteRegistry service

#Requires -RunAsAdministrator

# Define the service you want to disable and stop
$serviceName = "RemoteRegistry"

# Set the service startup type to "Disabled"
try {
	Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
	Write-Host "`nService '$serviceName' startup type set to Disabled." -ForegroundColor Green
}
catch {
	Write-Host "`nCould not set startup type for service '$serviceName'. Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Stop the service if it's currently running
try {
	Stop-Service -Name $serviceName -ErrorAction Stop
	Write-Host "Service '$serviceName' stopped successfully." -ForegroundColor Green
}
catch {
	Write-Host "`nCould not stop service '$serviceName'. Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n'$serviceName' service disabled and stopped successfully." -ForegroundColor Green

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.