# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script enables or disables LocalAccountTokenFilterPolicy in the Registry
# Enable: Allows local administrator accounts to perform remote admin tasks without UAC restrictions
# Disable: Restores default behavior, enforcing UAC token filtering for remote connections

# Optional flags:
#     -Disable: Disable LocalAccountTokenFilterPolicy without prompting
#     -Enable:  Enable LocalAccountTokenFilterPolicy without prompting
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
	Write-Host "  -Disable  Disable LocalAccountTokenFilterPolicy without prompting" -ForegroundColor Cyan
	Write-Host "  -Enable   Enable LocalAccountTokenFilterPolicy without prompting" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# If neither flag is passed, fall through to interactive menu
if (-not $Enable -and -not $Disable) {
	Write-Host "`n1. Enable LocalAccountTokenFilterPolicy"
	Write-Host "2. Disable LocalAccountTokenFilterPolicy"
	Write-Host "`nPress 1 or 2 to continue..." -ForegroundColor Cyan

	while ($true) {
		$key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
		if ($key -eq '1' -or $key -eq '2') { break }
		Write-Host ""
		Write-Warning "Invalid input. Please press 1 or 2..."
	}

	$Enable = $key -eq '1'
	$Disable = $key -eq '2'
}

$enabling = $Enable -eq $true
$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

Write-Host "`nChecking LocalAccountTokenFilterPolicy status..." -ForegroundColor Cyan

try {
	if (-not (Test-Path $regPath)) {
		New-Item -Path $regPath -Force | Out-Null
	}

	$currentValue = (Get-ItemProperty -Path $regPath -Name "LocalAccountTokenFilterPolicy" -ErrorAction SilentlyContinue).LocalAccountTokenFilterPolicy

	if ($enabling) {
		if ($currentValue -eq 1) {
			Write-Host ""
			Write-Warning "LocalAccountTokenFilterPolicy is already enabled."
			exit 0
		}
		Set-ItemProperty -Path $regPath -Name "LocalAccountTokenFilterPolicy" -Type DWord -Value 1 -Force -ErrorAction Stop
		Write-Host "`n$ScriptName`: LocalAccountTokenFilterPolicy enabled successfully." -ForegroundColor Green
	}
	else {
		if ($currentValue -eq 0 -or $null -eq $currentValue) {
			Write-Host ""
			Write-Warning "LocalAccountTokenFilterPolicy is already disabled."
			exit 0
		}
		Set-ItemProperty -Path $regPath -Name "LocalAccountTokenFilterPolicy" -Type DWord -Value 0 -Force -ErrorAction Stop
		Write-Host "`n$ScriptName`: LocalAccountTokenFilterPolicy disabled successfully." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	if ($enabling) {
		Write-Error "$ScriptName`: Failed to enable LocalAccountTokenFilterPolicy: $($_.Exception.Message)"
	}
	else {
		Write-Error "$ScriptName`: Failed to disable LocalAccountTokenFilterPolicy: $($_.Exception.Message)"
	}
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.