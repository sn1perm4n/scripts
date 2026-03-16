# This script stops and disables the Intel Driver and Support Assistant services and must be run as Administrator, which requires the following:
# 1. Create a shortcut to the .ps1 file and set the "Target" field to C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& C:\Users\<PROFILE>\Scripts"
# 2. Enable "Run as administrator" in the Shortcut tab -> Advanced)
#Requires -RunAsAdministrator

# Ensure script runs as Administrator
$principal = New-Object Security.Principal.WindowsPrincipal `
	([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $principal.IsInRole(
	[Security.Principal.WindowsBuiltInRole]::Administrator
)) {
	Write-Host "Please run this script as Administrator. Press any key to exit..." -ForegroundColor Red
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit 1
}

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