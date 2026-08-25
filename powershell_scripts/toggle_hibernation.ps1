# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script enables or disables Hibernation

# Check Hibernation status via the registry (preferred for scripting):
# Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Power -Name HibernateEnabled
# Or alternately, check available sleep states using PowerCfg in the Command Prompt:
# powercfg /a
# - If "Hibernate" appears under "The following sleep states are available", it is enabled
# - If it appears under "not available" or is missing, it is disabled

# Optional flags:
#     -Disable: Disable Hibernation without prompting
#     -Enable:  Enable Hibernation without prompting
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
	Write-Host "  -Disable  Disable Hibernation without prompting" -ForegroundColor Cyan
	Write-Host "  -Enable   Enable Hibernation without prompting" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# If neither flag is passed, fall through to interactive menu
if (-not $Enable -and -not $Disable) {
	Write-Host "`n1. Enable Hibernation"
	Write-Host "2. Disable Hibernation"
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

try {
	Write-Host "`nChecking Hibernation status..." -ForegroundColor Cyan
	$hibernationEnabled = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Power -Name HibernateEnabled).HibernateEnabled -eq 1

	if ($enabling) {
		if ($hibernationEnabled) {
			Write-Host ""
			Write-Warning "Hibernation is already enabled."
			exit 0
		}
		Write-Host "`nEnabling Hibernation..." -ForegroundColor Cyan
		powercfg.exe /hibernate on
		$hibernationEnabled = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Power -Name HibernateEnabled).HibernateEnabled -eq 1
		if ($hibernationEnabled) {
			Write-Host "`n$ScriptName`: Hibernation enabled successfully." -ForegroundColor Green
		}
		else {
			Write-Host ""
			Write-Error "$ScriptName`: Hibernation enable verification failed."
			exit 1
		}
	}
	else {
		if (-not $hibernationEnabled) {
			Write-Host ""
			Write-Warning "Hibernation is already disabled."
			exit 0
		}
		Write-Host "`nDisabling Hibernation..." -ForegroundColor Cyan
		powercfg.exe /hibernate off
		$hibernationEnabled = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Power -Name HibernateEnabled).HibernateEnabled -eq 1
		if (-not $hibernationEnabled) {
			Write-Host "`n$ScriptName`: Hibernation disabled successfully." -ForegroundColor Green
		}
		else {
			Write-Host ""
			Write-Error "$ScriptName`: Hibernation disable verification failed."
			exit 1
		}
	}
}
catch {
	Write-Host ""
	if ($enabling) {
		Write-Error "$ScriptName`: An error occurred while enabling Hibernation: $($_.Exception.Message)"
	}
	else {
		Write-Error "$ScriptName`: An error occurred while disabling Hibernation: $($_.Exception.Message)"
	}
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.