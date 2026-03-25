# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script starts the Intel Driver and Support Assistant services

#Requires -RunAsAdministrator

# Define the service names you want to enable and start
$dsaService = "DSAService"
$dsaUpdateService = "DSAUpdateService"

# Set the service startup type to "Automatic"
try {
	Set-Service -Name $dsaService -StartupType Automatic -ErrorAction Stop
	Write-Host "Service '$dsaService' startup type set to Automatic."
	Set-Service -Name $dsaUpdateService -StartupType Automatic -ErrorAction Stop
	Write-Host "Service '$dsaUpdateService' startup type set to Automatic."
}
catch {
	Write-Host "Could not set startup type for service '$dsaService'. Error: $($_.Exception.Message)"
	Write-Host "Could not set startup type for service '$dsaUpdateService'. Error: $($_.Exception.Message)"
}

# Start the DSAService and DSAUpdateService services
try {
	Start-Service -Name $dsaService -ErrorAction Stop
	Write-Host "Service '$dsaService' started successfully."
	Start-Service -Name $dsaUpdateService -ErrorAction Stop
	Write-Host "Service '$dsaUpdateService' started successfully."
}
catch {
	Write-Host "Could not start service '$dsaService'. Error: $($_.Exception.Message)"
	Write-Host "Could not start service '$dsaUpdateService'. Error: $($_.Exception.Message)"
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.