# This script stops and disables the DiagTrack service (otherwise known as "Connected User Experiences and Telemetry") and must be run as Administrator, which requires the following:
# 1. Create a shortcut to the .ps1 file, set the "Target" field to C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& C:\Users\<PROFILE>\Scripts\disable_connected_user_experiences_service.ps1"
# 2. Enable "Run as administrator" in the Shortcut tab -> Advanced)
# In order for this script to run during startup, the script needs to be in C:\Users\<PROFILE>\Scripts, and a "Run as administrator" shortcut to the .ps1 file must be copied to C:\WINDOWS\System32\GroupPolicy\Machine\Scripts\Startup. The script in C:\Users\<PROFILE>\Scripts then needs to be put into gpedit.msc -> Computer Configuration -> Windows Settings -> Scripts (Startup/Shutdown) -> Startup -> PowerShell Scripts tab ("Script Parameters" needs to be "-ExecutionPolicy Bypass")

# Define the service name you want to stop and disable
$servicenameDiagTrack = "DiagTrack"

# Stop the service
try {
    Stop-Service -Name $servicenameDiagTrack -Force -ErrorAction Stop
    Write-Host "Service '$servicenameDiagTrack' stopped successfully."
}
catch {
    Write-Host "Could not stop service '$servicenameDiagTrack'. Error: $($_.Exception.Message)"
}

# Disable the service startup type
try {
    Set-Service -Name $servicenameDiagTrack -StartupType Disabled -ErrorAction Stop
    Write-Host "Service '$servicenameDiagTrack' startup type set to Disabled."
}
catch {
    Write-Host "Could not set startup type for service '$servicenameDiagTrack'. Error: $($_.Exception.Message)"
}

Write-Host "The 'Connected Users Experiences and Telemetry' service has been disabled."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.