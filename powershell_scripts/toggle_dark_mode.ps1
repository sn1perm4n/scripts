# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script enables or disables dark mode in Windows 10 and 11 (activation not required)

# Optional flags:
#     -Disable:   Disable dark mode without prompting
#     -Enable:    Enable dark mode without prompting
#     -Preview:   Report current dark mode status without changing anything
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Disable,
	[switch]$Enable,
	[switch]$Preview,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Disable] [-Enable] [-Preview] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Disable  Disable dark mode without prompting" -ForegroundColor Cyan
	Write-Host "  -Enable   Enable dark mode without prompting" -ForegroundColor Cyan
	Write-Host "  -Preview  Report current dark mode status without changing anything" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

$regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

# -Enable and -Disable are mutually exclusive
if ($Enable -and $Disable) {
	Write-Host ""
	Write-Error "-Enable and -Disable are mutually exclusive."
	exit 1
}

# -Preview reports current status and bypasses the interactive menu entirely
if ($Preview) {
	try {
		if (-not (Test-Path $regPath)) {
			Write-Host "Dark mode registry key not found; Windows defaults to light mode until first configured."
			exit 0
		}

		$props = Get-ItemProperty -Path $regPath -ErrorAction Stop
		$appsLight = $props.AppsUseLightTheme
		$systemLight = $props.SystemUsesLightTheme

		if ($appsLight -eq 0 -and $systemLight -eq 0) {
			Write-Host "Dark mode is currently ENABLED (Apps and System)."
		}
		elseif ($appsLight -eq 1 -and $systemLight -eq 1) {
			Write-Host "Dark mode is currently DISABLED (Apps and System)."
		}
		else {
			$appsState = if ($appsLight -eq 0) { "Dark" } else { "Light" }
			$systemState = if ($systemLight -eq 0) { "Dark" } else { "Light" }
			Write-Host "Dark mode is in a mixed state: Apps=$appsState, System=$systemState."
		}
	}
	catch {
		Write-Host ""
		Write-Error "$ScriptName`: Failed to check dark mode status: $($_.Exception.Message)"
		exit 1
	}

	exit 0
}

# If neither flag is passed, fall through to interactive menu
if (-not $Enable -and -not $Disable) {
	Write-Host "`n1. Enable dark mode"
	Write-Host "2. Disable dark mode"
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
$value = if ($enabling) { 0 }
else { 1 }

Write-Host "`nChecking dark mode status..." -ForegroundColor Cyan

try {
	if (-not (Test-Path $regPath)) {
		New-Item -Path $regPath -Force | Out-Null
	}

	$props = Get-ItemProperty -Path $regPath -ErrorAction Stop
	$appsLight = $props.AppsUseLightTheme
	$systemLight = $props.SystemUsesLightTheme

	if ($enabling -and $appsLight -eq 0 -and $systemLight -eq 0) {
		Write-Host ""
		Write-Warning "Dark mode is already enabled."
		exit 0
	}
	if (-not $enabling -and $appsLight -eq 1 -and $systemLight -eq 1) {
		Write-Host ""
		Write-Warning "Dark mode is already disabled."
		exit 0
	}

	Set-ItemProperty -Path $regPath -Name "AppsUseLightTheme" -Type DWord -Value $value -Force -ErrorAction Stop
	Set-ItemProperty -Path $regPath -Name "SystemUsesLightTheme" -Type DWord -Value $value -Force -ErrorAction Stop

	if ($enabling) {
		Write-Host "`n$ScriptName`: Dark mode enabled successfully." -ForegroundColor Green
	}
	else {
		Write-Host "`n$ScriptName`: Dark mode disabled successfully." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	if ($enabling) {
		Write-Error "$ScriptName`: Failed to enable dark mode: $($_.Exception.Message)"
	}
	else {
		Write-Error "$ScriptName`: Failed to disable dark mode: $($_.Exception.Message)"
	}
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.