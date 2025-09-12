# This script starts the Intel Driver and Support Assistant services and must be run as Administrator, which requires the following:
# 1. Create a shortcut to the .ps1 file and set the "Target" field to C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& C:\Users\<PROFILE>\Scripts"
# 2. Enable "Run as administrator" in the Shortcut tab -> Advanced)

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