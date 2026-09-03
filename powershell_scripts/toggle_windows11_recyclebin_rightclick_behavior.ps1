# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script toggles the Recycle Bin right-click context menu between Windows 10 and Windows 11 style

# NOTE: This script is intended for Windows 11 only

# NOTE2: File Explorer will be restarted automatically to apply changes — a Taskbar redraw delay of up to ~30 seconds is normal

# NOTE3: Restarting File Explorer can cause the Nvidia system tray icon to disappear, since Nvidia's tray component does not always respond to the TaskbarCreated broadcast Explorer sends on restart. This script automatically restarts the NVIDIA Display Container LS service (if present) to work around it; this is a no-op on machines without an Nvidia GPU.

# Optional flags:
#     -Preview:   Report current right-click menu style without changing anything
#     -Windows10: Switch to Windows 10 style right-click menu without prompting
#     -Windows11: Switch to Windows 11 style right-click menu without prompting
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Preview,
	[switch]$Windows10,
	[switch]$Windows11,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Preview] [-Windows10] [-Windows11] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Preview    Report current right-click menu style without changing anything" -ForegroundColor Cyan
	Write-Host "  -Windows10  Switch to Windows 10 style right-click menu without prompting" -ForegroundColor Cyan
	Write-Host "  -Windows11  Switch to Windows 11 style right-click menu without prompting" -ForegroundColor Cyan
	Write-Host "  -Help       Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# -Windows10 and -Windows11 are mutually exclusive
if ($Windows10 -and $Windows11) {
	Write-Host ""
	Write-Error "-Windows10 and -Windows11 are mutually exclusive."
	exit 1
}

$regPath = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
$regParent = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'

# -Preview reports current status and bypasses the interactive menu entirely
if ($Preview) {
	if (Test-Path $regPath) {
		Write-Host "Windows 10 style right-click menu is currently active."
	}
	else {
		Write-Host "Windows 11 style right-click menu is currently active."
	}
	exit 0
}

if (-not $Windows10 -and -not $Windows11) {
	Write-Host "`n1. Switch to Windows 10 style right-click menu"
	Write-Host "2. Switch to Windows 11 style right-click menu"
	Write-Host "`nPress 1 or 2 to continue..." -ForegroundColor Cyan

	while ($true) {
		$key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
		if ($key -eq '1' -or $key -eq '2') { break }
		Write-Host ""
		Write-Warning "Invalid input. Please press 1 or 2..."
	}

	$Windows10 = $key -eq '1'
	$Windows11 = $key -eq '2'
}

$usingWindows10Style = $Windows10 -eq $true

Write-Host "`nChecking right-click menu style..." -ForegroundColor Cyan

try {
	if ($usingWindows10Style) {
		if (Test-Path $regPath) {
			Write-Host ""
			Write-Warning "Windows 10 style right-click menu is already active."
			exit 0
		}
		New-Item -Path $regPath -Value "" -Force | Out-Null
		Write-Host "`n$ScriptName`: Switched to Windows 10 style right-click menu successfully." -ForegroundColor Green
	}
	else {
		if (-not (Test-Path $regParent)) {
			Write-Host ""
			Write-Warning "Windows 11 style right-click menu is already active."
			exit 0
		}
		Remove-Item -Path $regParent -Recurse -Force -ErrorAction Stop
		Write-Host "`n$ScriptName`: Switched to Windows 11 style right-click menu successfully." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	if ($usingWindows10Style) {
		Write-Error "$ScriptName`: Failed to switch to Windows 10 style right-click menu: $($_.Exception.Message)"
	}
	else {
		Write-Error "$ScriptName`: Failed to switch to Windows 11 style right-click menu: $($_.Exception.Message)"
	}
	exit 1
}

try {
	Write-Host "`nRestarting File Explorer..." -ForegroundColor Cyan
	Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
	Start-Sleep -Seconds 2
	Start-Process explorer
	Write-Host "`n$ScriptName`: File Explorer restarted successfully." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Error "$ScriptName`: Failed to restart File Explorer: $($_.Exception.Message)"
	exit 1
}

# Restart the Nvidia Display Container LS service if present, since the Explorer restart above can cause the Nvidia system tray icon to disappear
$nvidiaServiceName = "NVDisplay.ContainerLocalSystem"
$nvidiaService = Get-Service -Name $nvidiaServiceName -ErrorAction SilentlyContinue
if ($nvidiaService) {
	Write-Host "`nRestarting NVIDIA Display Container LS service to restore its system tray icon..." -ForegroundColor Cyan
	try {
		Stop-Service -Name $nvidiaServiceName -Force -ErrorAction Stop
		Start-Service -Name $nvidiaServiceName -ErrorAction Stop
		Write-Host "NVIDIA Display Container LS service restarted successfully." -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Warning "Could not restart NVIDIA Display Container LS service: $($_.Exception.Message)"
	}
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.