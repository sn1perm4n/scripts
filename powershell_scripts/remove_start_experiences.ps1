# This script removes Microsoft Start Experiences App and must be run as Administrator, which requires the following:
# 1. Create a shortcut to the .ps1 file, set the "Target" field to C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& C:\Users\<PROFILE>\Scripts\remove_start_experiences.ps1"
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

# Remove Start Experiences
Get-AppxPackage -Name Microsoft.StartExperiencesApp | Remove-AppxPackage -ErrorAction SilentlyContinue

Write-Host "Successfully uninstalled 'Microsoft Start Experiences App'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.