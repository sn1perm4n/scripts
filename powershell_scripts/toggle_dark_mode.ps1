# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script enables or disables dark mode in Windows 10 and 11 (activation not required)

# Optional flags:
#     -Disable: Disable dark mode without prompting
#     -Enable:  Enable dark mode without prompting
#     -Help / -?: Display this help message

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
	Write-Host "  -Disable  Disable dark mode without prompting" -ForegroundColor Cyan
	Write-Host "  -Enable   Enable dark mode without prompting" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

$regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

# If neither flag is passed, fall through to interactive menu
if (-not $Enable -and -not $Disable) {
	Write-Host "`n1. Enable dark mode"
	Write-Host "2. Disable dark mode"
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
$value = if ($enabling) { 0 } else { 1 }

Write-Host "`nChecking dark mode status..." -ForegroundColor Cyan

try {
	if (-not (Test-Path $regPath)) {
		New-Item -Path $regPath -Force | Out-Null
	}

	$props = Get-ItemProperty -Path $regPath -ErrorAction Stop
	$appsLight = $props.AppsUseLightTheme
	$systemLight = $props.SystemUsesLightTheme

	if ($enabling -and $appsLight -eq 0 -and $systemLight -eq 0) {
		Write-Host "`nDark mode is already enabled." -ForegroundColor Yellow
		exit 0
	}
	if (-not $enabling -and $appsLight -eq 1 -and $systemLight -eq 1) {
		Write-Host "`nDark mode is already disabled." -ForegroundColor Yellow
		exit 0
	}

	Set-ItemProperty -Path $regPath -Name "AppsUseLightTheme" -Type DWord -Value $value -Force -ErrorAction Stop
	Set-ItemProperty -Path $regPath -Name "SystemUsesLightTheme" -Type DWord -Value $value -Force -ErrorAction Stop

	if ($enabling) {
		Write-Host "`nDark mode successfully enabled." -ForegroundColor Green
	}
	else {
		Write-Host "`nDark mode successfully disabled." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	if ($enabling) {
		Write-Error "Failed to enable dark mode: $($_.Exception.Message)"
	}
	else {
		Write-Error "Failed to disable dark mode: $($_.Exception.Message)"
	}
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.