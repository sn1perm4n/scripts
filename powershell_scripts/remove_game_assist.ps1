# This script removes Microsoft Game Assist (automatically reinstalls itself when Microsoft Edge updates) and must be run as Administrator, which requires the following:
# 1. Create a shortcut to the .ps1 file, set the "Target" field to C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& C:\Users\<PROFILE>\Scripts\remove_game_assist.ps1"
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

# Remove Game Assist
Get-AppxPackage -Name Microsoft.Edge.GameAssist | Remove-AppxPackage -ErrorAction SilentlyContinue

Write-Host "Successfully uninstalled 'Game Assist'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.