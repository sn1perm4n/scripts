# This script starts and enables the "Intel Driver and Support Assistant" services and must be run as Administrator, which requires the following:
# 1. Create a shortcut to the .ps1 file and set the "Target" field to C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& C:\Users\<PROFILE>\Scripts\enable_intel_driver_support_assistant_services.ps1"
# 2. Enable "Run as administrator" in the Shortcut tab -> Advanced)

# Define the service names you want to enable and start
$servicenameDSAService = "DSAService"
$servicenameDSAUpdateService = "DSAUpdateService"

# Set the service startup type to "Automatic"
try {
    Set-Service -Name $servicenameDSAService -StartupType Automatic -ErrorAction Stop
    Write-Host "Service '$servicenameDSAService' startup type set to Automatic."
	Set-Service -Name $servicenameDSAUpdateService -StartupType Automatic -ErrorAction Stop
	Write-Host "Service '$servicenameDSAUpdateService' startup type set to Automatic."
}
catch {
    Write-Host "Could not set startup type for service '$servicenameDSAService'. Error: $($_.Exception.Message)"
	Write-Host "Could not set startup type for service '$servicenameDSAUpdateService'. Error: $($_.Exception.Message)"
}

# Start the DSAService and DSAUpdateService services
try {
    Start-Service -Name $servicenameDSAService -ErrorAction Stop
    Write-Host "Service '$servicenameDSAService' started successfully."
	Start-Service -Name $servicenameDSAUpdateService -ErrorAction Stop
	Write-Host "Service '$servicenameDSAUpdateService' started successfully."
}
catch {
    Write-Host "Could not start service '$servicenameDSAService'. Error: $($_.Exception.Message)"
	Write-Host "Could not start service '$servicenameDSAUpdateService'. Error: $($_.Exception.Message)"
}

Write-Host "The 'Intel Driver & Support Assistant' services have been enabled."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.