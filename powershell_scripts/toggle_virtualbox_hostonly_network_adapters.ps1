# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script enables or disables all VirtualBox Host-Only Ethernet Adapters in Device Manager

# Optional flags:
#     -Disable: Disable all VirtualBox Host-Only Ethernet Adapters without prompting
#     -Enable: Enable all VirtualBox Host-Only Ethernet Adapters without prompting
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

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Disable] [-Enable] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Disable  Disable all VirtualBox Host-Only Ethernet Adapters without prompting" -ForegroundColor Cyan
	Write-Host "  -Enable   Enable all VirtualBox Host-Only Ethernet Adapters without prompting" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

if ($Disable -and $Enable) {
	Write-Host ""
	Write-Warning "-Disable and -Enable cannot be used together."
	exit 1
}

# If neither flag is passed, fall through to interactive menu
if (-not $Disable -and -not $Enable) {
	Write-Host "`n1. Enable all VirtualBox Host-Only Ethernet Adapters"
	Write-Host "2. Disable all VirtualBox Host-Only Ethernet Adapters"
	Write-Host "`nPress 1 or 2 to continue..." -ForegroundColor Cyan

	while ($true) {
		$key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
		if ($key -eq '1' -or $key -eq '2') { break }
		Write-Host "`nInvalid input. Please press 1 or 2..." -ForegroundColor Yellow
	}

	$Enable = $key -eq '1'
	$Disable = $key -eq '2'
}

Write-Host "`nSearching for VirtualBox Host-Only Ethernet Adapters..." -ForegroundColor Cyan

$adapters = Get-PnpDevice | Where-Object {
	$_.FriendlyName -match 'VirtualBox Host-Only'
}

if (-not $adapters) {
	Write-Host ""
	Write-Error "No VirtualBox Host-Only Ethernet Adapters found. Is VirtualBox installed?"
	exit 1
}

Write-Host "Found $($adapters.Count) adapter(s):" -ForegroundColor Cyan
foreach ($adapter in $adapters) {
	Write-Host "  $($adapter.FriendlyName) — Status: $($adapter.Status)"
}

Write-Host ""

$changedCount = 0
$alreadyCount = 0

foreach ($adapter in $adapters) {
	if ($Enable) {
		if ($adapter.Status -eq 'OK') {
			Write-Warning "Already enabled: $($adapter.FriendlyName)"
			$alreadyCount++
		}
		else {
			try {
				Enable-PnpDevice -InstanceId $adapter.InstanceId -Confirm:$false -ErrorAction Stop
				Write-Host "Enabled: $($adapter.FriendlyName)" -ForegroundColor Green
				$changedCount++
			}
			catch {
				Write-Host ""
				Write-Warning "$ScriptName`: Could not enable $($adapter.FriendlyName): $($_.Exception.Message)"
			}
		}
	}
	else {
		if ($adapter.Status -eq 'Error' -or $adapter.Status -eq 'Unknown') {
			Write-Warning "Already disabled: $($adapter.FriendlyName)"
			$alreadyCount++
		}
		else {
			try {
				Disable-PnpDevice -InstanceId $adapter.InstanceId -Confirm:$false -ErrorAction Stop
				Write-Host "Disabled: $($adapter.FriendlyName)" -ForegroundColor Green
				$changedCount++
			}
			catch {
				Write-Host ""
				Write-Warning "$ScriptName`: Could not disable $($adapter.FriendlyName): $($_.Exception.Message)"
			}
		}
	}
}

$action = if ($Enable) { "enabled" } else { "disabled" }
$summaryLine = "$ScriptName`: $changedCount adapter(s) $action, $alreadyCount already $action."
if ($changedCount -gt 0) {
	Write-Host "`n$summaryLine" -ForegroundColor Green
}
else {
	Write-Host ""
	Write-Warning $summaryLine
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.