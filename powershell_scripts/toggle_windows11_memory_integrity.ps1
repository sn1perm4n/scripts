# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script toggles Windows 11 Memory Integrity (Hypervisor-protected Code Integrity / HVCI)

# NOTE: A reboot is required for changes to take effect

# NOTE2: Disabling Memory Integrity can improve performance in some games and CPU-intensive workloads, but it also disables a real protection against certain kernel-level exploits and malicious drivers

# Optional flags:
#     -Disable:   Disable Memory Integrity without prompting
#     -Enable:    Enable Memory Integrity without prompting
#     -Preview:   Report current Memory Integrity status without changing anything
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

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
	Write-Host "  -Disable  Disable Memory Integrity without prompting" -ForegroundColor Cyan
	Write-Host "  -Enable   Enable Memory Integrity without prompting" -ForegroundColor Cyan
	Write-Host "  -Preview  Report current Memory Integrity status without changing anything" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# -Enable and -Disable are mutually exclusive
if ($Enable -and $Disable) {
	Write-Host ""
	Write-Error "-Enable and -Disable are mutually exclusive."
	exit 1
}

$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'

# -Preview reports current status and bypasses the interactive menu entirely
if ($Preview) {
	try {
		$currentValue = if (Test-Path $regPath) { (Get-ItemProperty -Path $regPath -Name "Enabled" -ErrorAction SilentlyContinue).Enabled } else { $null }

		if ($currentValue -eq 1) {
			Write-Host "Memory Integrity is currently ENABLED."
		}
		else {
			Write-Host "Memory Integrity is currently DISABLED."
		}
	}
	catch {
		Write-Host ""
		Write-Error "$ScriptName`: Failed to check Memory Integrity status: $($_.Exception.Message)"
		exit 1
	}

	exit 0
}

# If neither flag is passed, fall through to interactive menu
if (-not $Enable -and -not $Disable) {
	Write-Host "`n1. Enable Memory Integrity"
	Write-Host "2. Disable Memory Integrity"
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
$targetValue = if ($enabling) { 1 } else { 0 }

Write-Host "`nChecking Memory Integrity status..." -ForegroundColor Cyan

try {
	if (-not (Test-Path $regPath)) {
		New-Item -Path $regPath -Force | Out-Null
	}

	$currentValue = (Get-ItemProperty -Path $regPath -Name "Enabled" -ErrorAction SilentlyContinue).Enabled

	if ($currentValue -eq $targetValue) {
		Write-Host ""
		if ($enabling) {
			Write-Warning "Memory Integrity is already enabled."
		}
		else {
			Write-Warning "Memory Integrity is already disabled."
		}
		exit 0
	}

	Set-ItemProperty -Path $regPath -Name "Enabled" -Value $targetValue -Type DWord -Force -ErrorAction Stop

	if ($enabling) {
		Write-Host "`n$ScriptName`: Memory Integrity enabled successfully. A reboot is required for this change to take effect." -ForegroundColor Green
	}
	else {
		Write-Host "`n$ScriptName`: Memory Integrity disabled successfully. A reboot is required for this change to take effect." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	if ($enabling) {
		Write-Error "$ScriptName`: Failed to enable Memory Integrity: $($_.Exception.Message)"
	}
	else {
		Write-Error "$ScriptName`: Failed to disable Memory Integrity: $($_.Exception.Message)"
	}
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.