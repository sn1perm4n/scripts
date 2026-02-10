# This script removes Microsoft Edge Game Assist (automatically reinstalls itself when Microsoft Edge updates) and must be run as Administrator, which requires the following:
# 1. Create a shortcut to the .ps1 file, set the "Target" field to C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& C:\Users\<USERNAME>\Scripts\uninstall_game_assist.ps1"
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

# Check for and remove Microsoft Edge Game Assist if installed
if (-not (Get-AppxPackage -Name Microsoft.Edge.GameAssist)) {
	Write-Host "Microsoft Edge Game Assist is not installed. Nothing to remove." -ForegroundColor Yellow
	return
}

try {
	Get-AppxPackage -Name Microsoft.Edge.GameAssist |
		Remove-AppxPackage -ErrorAction Stop

	Write-Host "Successfully uninstalled Microsoft Edge Game Assist." -ForegroundColor Green
}
catch {
	Write-Host "Failed to uninstall Microsoft Edge Game Assist: $($_.Exception.Message)." -ForegroundColor Red
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.