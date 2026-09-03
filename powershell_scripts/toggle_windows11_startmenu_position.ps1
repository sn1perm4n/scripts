# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script toggles the Start button/Taskbar icon alignment between left (Windows 10 style) and center (Windows 11 default)

# NOTE: File Explorer will be restarted automatically to apply changes — a Taskbar redraw delay of up to ~30 seconds is normal

# NOTE2: Restarting File Explorer can cause the Nvidia system tray icon to disappear, since Nvidia's tray component does not always respond to the TaskbarCreated broadcast Explorer sends on restart. This script automatically restarts the NVIDIA Display Container LS service (if present) to work around it; this is a no-op on machines without an Nvidia GPU.

# Optional flags:
#     -Center:    Switch to center Start button position without prompting
#     -Left:      Switch to left Start button position without prompting
#     -Preview:   Report current Start button position without changing anything
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Center,
	[switch]$Left,
	[switch]$Preview,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Center] [-Left] [-Preview] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Center   Switch to center Start button position without prompting" -ForegroundColor Cyan
	Write-Host "  -Left     Switch to left Start button position without prompting" -ForegroundColor Cyan
	Write-Host "  -Preview  Report current Start button position without changing anything" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# -Center and -Left are mutually exclusive
if ($Center -and $Left) {
	Write-Host ""
	Write-Error "-Center and -Left are mutually exclusive."
	exit 1
}

$regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$regName = 'TaskbarAl'

# -Preview reports current status and bypasses the interactive menu entirely
if ($Preview) {
	try {
		$currentValue = if (Test-Path $regPath) { (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName } else { $null }

		if ($currentValue -eq 0) {
			Write-Host "Start button position is currently LEFT."
		}
		else {
			# TaskbarAl defaults to 1 (center) when not explicitly set
			Write-Host "Start button position is currently CENTER."
		}
	}
	catch {
		Write-Host ""
		Write-Error "$ScriptName`: Failed to check Start button position: $($_.Exception.Message)"
		exit 1
	}

	exit 0
}

# If neither flag is passed, fall through to interactive menu
if (-not $Center -and -not $Left) {
	Write-Host "`n1. Switch to left Start button position"
	Write-Host "2. Switch to center Start button position"
	Write-Host "`nPress 1 or 2 to continue..." -ForegroundColor Cyan

	while ($true) {
		$key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
		if ($key -eq '1' -or $key -eq '2') { break }
		Write-Host ""
		Write-Warning "Invalid input. Please press 1 or 2..."
	}

	$Left = $key -eq '1'
	$Center = $key -eq '2'
}

$usingLeft = $Left -eq $true
$targetValue = if ($usingLeft) { 0 } else { 1 }

Write-Host "`nChecking Start button position..." -ForegroundColor Cyan

try {
	if (-not (Test-Path $regPath)) {
		New-Item -Path $regPath -Force | Out-Null
	}

	$currentValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName

	if ($currentValue -eq $targetValue) {
		Write-Host ""
		if ($usingLeft) {
			Write-Warning "Left Start button position is already active."
		}
		else {
			Write-Warning "Center Start button position is already active."
		}
		exit 0
	}

	Set-ItemProperty -Path $regPath -Name $regName -Value $targetValue -Type DWord -Force -ErrorAction Stop

	if ($usingLeft) {
		Write-Host "`n$ScriptName`: Switched to left Start button position successfully." -ForegroundColor Green
	}
	else {
		Write-Host "`n$ScriptName`: Switched to center Start button position successfully." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	if ($usingLeft) {
		Write-Error "$ScriptName`: Failed to switch to left Start button position: $($_.Exception.Message)"
	}
	else {
		Write-Error "$ScriptName`: Failed to switch to center Start button position: $($_.Exception.Message)"
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