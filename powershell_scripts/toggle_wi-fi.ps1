# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script enables or disables Wi-Fi. The name of your Wi-Fi adapter may differ so confirm first with the following PowerShell command (if you don't do this you'll see a bunch of red errors):
# Get-NetAdapter

# Optional flags:
#     -Disable: Disable Wi-Fi without prompting
#     -Enable:  Enable Wi-Fi without prompting
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Disable,
	[switch]$Enable,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Disable] [-Enable] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Disable  Disable Wi-Fi without prompting" -ForegroundColor Cyan
	Write-Host "  -Enable   Enable Wi-Fi without prompting" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host "`nNote: Your Wi-Fi adapter name may differ. Confirm it first with:" -ForegroundColor Cyan
	Write-Host "    Get-NetAdapter" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# If neither flag is passed, fall through to interactive menu
if (-not $Enable -and -not $Disable) {
	Write-Host "`n1. Enable Wi-Fi"
	Write-Host "2. Disable Wi-Fi"
	Write-Host "`nPress 1 or 2 to continue..." -ForegroundColor Cyan

	while ($true) {
		$key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
		if ($key -eq '1' -or $key -eq '2') { break }
		Write-Host "`nInvalid input. Please press 1 or 2..." -ForegroundColor Yellow
	}

	$Enable = $key -eq '1'
	$Disable = $key -eq '2'
}

$enabling = $Enable -eq $true

try {
	Write-Host "`nChecking Wi-Fi status..." -ForegroundColor Cyan
	$adapter = Get-NetAdapter -Name "Wi-Fi" -ErrorAction Stop

	if ($enabling) {
		if ($adapter.Status -eq 'Up' -or $adapter.Status -eq 'Disconnected') {
			Write-Host ""
			Write-Warning "Wi-Fi is already enabled."
			exit 0
		}
		Enable-NetAdapter -Name "Wi-Fi" -Confirm:$false -ErrorAction Stop
		Write-Host "`n$ScriptName`: Wi-Fi enabled successfully." -ForegroundColor Green
	}
	else {
		if ($adapter.Status -eq 'Disabled') {
			Write-Host ""
			Write-Warning "Wi-Fi is already disabled."
			exit 0
		}
		Disable-NetAdapter -Name "Wi-Fi" -Confirm:$false -ErrorAction Stop
		Write-Host "`n$ScriptName`: Wi-Fi disabled successfully." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	if ($enabling) {
		Write-Error "$ScriptName`: An error occurred while enabling Wi-Fi: $($_.Exception.Message)"
	}
	else {
		Write-Error "$ScriptName`: An error occurred while disabling Wi-Fi: $($_.Exception.Message)"
	}
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.