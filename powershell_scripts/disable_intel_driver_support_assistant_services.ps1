# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script stops and disables the Intel Driver and Support Assistant services

#Requires -RunAsAdministrator

# Define the service names you want to disable and stop
$dsaService = "DSAService"
$dsaUpdateService = "DSAUpdateService"

# Set the service startup type to "Disabled"
try {
	Set-Service -Name $dsaService -StartupType Disabled -ErrorAction Stop
	Write-Host "Service '$dsaService' startup type set to Disabled."
	Set-Service -Name $dsaUpdateService -StartupType Disabled -ErrorAction Stop
	Write-Host "Service '$dsaUpdateService' startup type set to Disabled."
}
catch {
	Write-Host "Could not set startup type for service '$dsaService'. Error: $($_.Exception.Message)"
	Write-Host "Could not set startup type for service '$dsaUpdateService'. Error: $($_.Exception.Message)"
}

# Stop the DSAService and DSAUpdateService services
try {
	Stop-Service -Name $dsaService -Force -ErrorAction Stop
	Write-Host "Service '$dsaService' stopped successfully."
	Stop-Service -Name $dsaUpdateService -Force -ErrorAction Stop
	Write-Host "Service '$dsaUpdateService' stopped successfully."
}
catch {
	Write-Host "Could not stop service '$dsaService'. Error: $($_.Exception.Message)"
	Write-Host "Could not stop service '$dsaUpdateService'. Error: $($_.Exception.Message)"
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.