# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script configures the ForegroundLockTimeout registry value under HKCU\Control Panel\Desktop. ForegroundLockTimeout controls how long Windows waits before preventing a new window from stealing focus. Setting it to 0 disables the timeout entirely, allowing any window requesting foreground focus to receive it immediately. The default value is 0x30d40 (200000ms / ~200 seconds)

# NOTE: A reboot is required after changing this value for it to take effect

# NOTE2: This fix is particularly relevant when running AutoHotkey with elevated privileges (via UIA/Run as administrator). The integrity level mismatch between an admin-elevated AHK process and medium-integrity windows (such as File Explorer network share worker threads) can cause Windows to enforce ForegroundLockTimeout aggressively, preventing newly opened windows from receiving focus. Setting ForegroundLockTimeout to 0 resolves this. This issue appears to primarily affect Windows 10.

# NOTE3: Windows Update may reset ForegroundLockTimeout back to the default value. If the issue reappears after a Windows update, re-run this script and reboot.

# Optional flags:
#     -Default: Restore ForegroundLockTimeout to the Windows default (0x30d40 / 200000ms) without prompting
#     -Disable: Set ForegroundLockTimeout to 0 (disables the timeout) without prompting
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Default,
	[switch]$Disable,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Disable] [-Default] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Default  Restore ForegroundLockTimeout to the Windows default (0x30d40 / 200000ms) without prompting" -ForegroundColor Cyan
	Write-Host "  -Disable  Set ForegroundLockTimeout to 0 (disables the timeout) without prompting" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

$regPath = 'HKCU:\Control Panel\Desktop'
$regName = 'ForegroundLockTimeout'
$defaultValue = 0x30d40

# If neither flag is passed, fall through to interactive menu
if (-not $Disable -and -not $Default) {
	Write-Host "`n1. Disable ForegroundLockTimeout (set to 0)"
	Write-Host "2. Restore ForegroundLockTimeout to default (set to 0x30d40 / 200000ms)"
	Write-Host "`nPress 1 or 2 to continue..." -ForegroundColor Cyan

	while ($true) {
		$key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
		if ($key -eq '1' -or $key -eq '2') { break }
		Write-Host "`nInvalid input. Please press 1 or 2..." -ForegroundColor Yellow
	}

	$Disable = $key -eq '1'
	$Default = $key -eq '2'
}

$disabling = $Disable -eq $true

Write-Host "`nChecking ForegroundLockTimeout status..." -ForegroundColor Cyan

try {
	if (-not (Test-Path $regPath)) {
		New-Item -Path $regPath -Force | Out-Null
	}

	$currentValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName

	if ($disabling) {
		if ($currentValue -eq 0) {
			Write-Host "`nForegroundLockTimeout is already set to 0." -ForegroundColor Yellow
			exit 0
		}
		Set-ItemProperty -Path $regPath -Name $regName -Type DWord -Value 0 -Force -ErrorAction Stop
		Write-Host "`nForegroundLockTimeout successfully set to 0. Please reboot for the change to take effect." -ForegroundColor Green
	}
	else {
		if ($currentValue -eq $defaultValue) {
			Write-Host "`nForegroundLockTimeout is already set to the default value (0x30d40 / 200000ms)." -ForegroundColor Yellow
			exit 0
		}
		Set-ItemProperty -Path $regPath -Name $regName -Type DWord -Value $defaultValue -Force -ErrorAction Stop
		Write-Host "`nForegroundLockTimeout successfully restored to default (0x30d40 / 200000ms). Please reboot for the change to take effect." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	if ($disabling) {
		Write-Error "Failed to set ForegroundLockTimeout to 0: $($_.Exception.Message)"
	}
	else {
		Write-Error "Failed to restore ForegroundLockTimeout to default: $($_.Exception.Message)"
	}
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.