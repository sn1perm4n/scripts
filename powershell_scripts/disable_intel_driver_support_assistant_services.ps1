# This script stops and disables the "Intel Driver and Support Assistant" services and must be run as Administrator, which requires the following:
# 1. Create a shortcut to the .ps1 file and set the "Target" field to C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& C:\Users\<PROFILE>\Scripts\disable_intel_driver_support_assistant_services.ps1"
# 2. Enable "Run as administrator" in the Shortcut tab -> Advanced)

# Define the service names you want to disable and stop
$servicenameDSAService = "DSAService"
$servicenameDSAUpdateService = "DSAUpdateService"

# Set the service startup type to "Disabled"
try {
    Set-Service -Name $servicenameDSAService -StartupType Disabled -ErrorAction Stop
    Write-Host "Service '$servicenameDSAService' startup type set to Disabled."
	Set-Service -Name $servicenameDSAUpdateService -StartupType Disabled -ErrorAction Stop
	Write-Host "Service '$servicenameDSAUpdateService' startup type set to Disabled."
}
catch {
    Write-Host "Could not set startup type for service '$servicenameDSAService'. Error: $($_.Exception.Message)"
	Write-Host "Could not set startup type for service '$servicenameDSAUpdateService'. Error: $($_.Exception.Message)"
}

# Stop the DSAService and DSAUpdateService services
try {
    Stop-Service -Name $servicenameDSAService -Force -ErrorAction Stop
    Write-Host "Service '$servicenameDSAService' stopped successfully."
	Stop-Service -Name $servicenameDSAUpdateService -Force -ErrorAction Stop
	Write-Host "Service '$servicenameDSAUpdateService' stopped successfully."
}
catch {
    Write-Host "Could not stop service '$servicenameDSAService'. Error: $($_.Exception.Message)"
	Write-Host "Could not stop service '$servicenameDSAUpdateService'. Error: $($_.Exception.Message)"
}

Write-Host "The 'Intel Driver & Support Assistant' services have been disabled."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.