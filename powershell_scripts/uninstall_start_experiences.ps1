# This script removes Microsoft Start Experiences App and must be run as Administrator, which requires the following:
# 1. Create a shortcut to the .ps1 file, set the "Target" field to C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& C:\Users\<USERNAME>\Scripts\uninstall_start_experiences.ps1"
# 2. Enable "Run as administrator" in the Shortcut tab -> Advanced)

# NOTE: Replace <USERNAME> with your actual Windows username

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

# Check for and remove Start Experiences App if installed
if (-not (Get-AppxPackage -Name Microsoft.StartExperiencesApp)) {
	Write-Host "Start Experiences App is not installed. Nothing to remove." -ForegroundColor Yellow
	return
}

try {
	Get-AppxPackage -Name Microsoft.StartExperiencesApp |
		Remove-AppxPackage -ErrorAction Stop

	Write-Host "Successfully uninstalled Start Experiences App." -ForegroundColor Green
}
catch {
	Write-Host "Failed to uninstall Start Experiences App: $($_.Exception.Message)." -ForegroundColor Red
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.