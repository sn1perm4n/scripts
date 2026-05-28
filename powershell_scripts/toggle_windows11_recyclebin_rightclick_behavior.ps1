# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script toggles the Recycle Bin right-click context menu between Windows 10 and Windows 11 style

# NOTE: This script is intended for Windows 11 only

# NOTE2: File Explorer will be restarted automatically to apply changes — a Taskbar redraw delay of up to ~30 seconds is normal

# Optional flags:
#     -Windows10: Switch to Windows 10 style right-click menu without prompting
#     -Windows11: Switch to Windows 11 style right-click menu without prompting
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Windows10,
	[switch]$Windows11,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Windows10] [-Windows11] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Windows10  Switch to Windows 10 style right-click menu without prompting" -ForegroundColor Cyan
	Write-Host "  -Windows11  Switch to Windows 11 style right-click menu without prompting" -ForegroundColor Cyan
	Write-Host "  -Help       Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

if (-not $Windows10 -and -not $Windows11) {
	Write-Host "`n1. Switch to Windows 10 style right-click menu"
	Write-Host "2. Switch to Windows 11 style right-click menu"
	Write-Host "`nPress 1 or 2 to continue..." -ForegroundColor Cyan

	while ($true) {
		$key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
		if ($key -eq '1' -or $key -eq '2') { break }
		Write-Host "`nInvalid input. Please press 1 or 2..." -ForegroundColor Yellow
	}

	$Windows10 = $key -eq '1'
	$Windows11 = $key -eq '2'
}

$usingWindows10Style = $Windows10 -eq $true
$regPath = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
$regParent = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'

Write-Host "`nChecking right-click menu style..." -ForegroundColor Cyan

try {
	if ($usingWindows10Style) {
		if (Test-Path $regPath) {
			Write-Host "`nWindows 10 style right-click menu is already active." -ForegroundColor Yellow
			exit 0
		}
		New-Item -Path $regPath -Value "" -Force | Out-Null
		Write-Host "`nSwitched to Windows 10 style right-click menu successfully." -ForegroundColor Green
	}
	else {
		if (-not (Test-Path $regParent)) {
			Write-Host "`nWindows 11 style right-click menu is already active." -ForegroundColor Yellow
			exit 0
		}
		Remove-Item -Path $regParent -Recurse -Force -ErrorAction Stop
		Write-Host "`nSwitched to Windows 11 style right-click menu successfully." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	if ($usingWindows10Style) {
		Write-Error "Failed to switch to Windows 10 style right-click menu: $($_.Exception.Message)"
	}
	else {
		Write-Error "Failed to switch to Windows 11 style right-click menu: $($_.Exception.Message)"
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