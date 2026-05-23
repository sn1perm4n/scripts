# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script toggles the Recycle Bin right-click context menu between Windows 10 and Windows 11 style

# NOTE: This script is intended for Windows 11 only

# NOTE2: File Explorer will be restarted automatically to apply changes

# Optional flags:
#     -Disable: Restore Windows 11 style right-click menu without prompting
#     -Enable:  Enable Windows 10 style right-click menu without prompting
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Disable,
	[switch]$Enable,
	[switch]$Help
)

$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Disable] [-Enable] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Disable  Restore Windows 11 style right-click menu without prompting" -ForegroundColor Cyan
	Write-Host "  -Enable   Enable Windows 10 style right-click menu without prompting" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

if (-not $Enable -and -not $Disable) {
	Write-Host "`n1. Enable Windows 10 style right-click menu"
	Write-Host "2. Disable Windows 10 style right-click menu (restore Windows 11 default)"
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
$regPath = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
$regParent = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'

Write-Host "`nChecking Windows 10 style right-click menu status..." -ForegroundColor Cyan

try {
	if ($enabling) {
		if (Test-Path $regPath) {
			Write-Host "`nWindows 10 style right-click menu is already enabled." -ForegroundColor Yellow
			exit 0
		}
		New-Item -Path $regPath -Value "" -Force | Out-Null
		Write-Host "`nWindows 10 style right-click menu successfully enabled." -ForegroundColor Green
	}
	else {
		if (-not (Test-Path $regParent)) {
			Write-Host "`nWindows 10 style right-click menu is already disabled." -ForegroundColor Yellow
			exit 0
		}
		Remove-Item -Path $regParent -Recurse -Force -ErrorAction Stop
		Write-Host "`nWindows 10 style right-click menu successfully disabled." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	if ($enabling) {
		Write-Error "Failed to enable Windows 10 style right-click menu: $($_.Exception.Message)"
	}
	else {
		Write-Error "Failed to disable Windows 10 style right-click menu: $($_.Exception.Message)"
	}
	exit 1
}

try {
	Write-Host "`nRestarting File Explorer..." -ForegroundColor Cyan
	Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
	Start-Sleep -Seconds 2
	Start-Process explorer
	Write-Host "`nFile Explorer restarted successfully." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Error "Failed to restart File Explorer: $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.