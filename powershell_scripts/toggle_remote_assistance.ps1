# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script enables or disables Remote Assistance

# Optional flags:
#     -Disable:   Disable Remote Assistance without prompting
#     -Enable:    Enable Remote Assistance without prompting
#     -Preview:   Report current Remote Assistance registry and firewall status without changing anything
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
	Write-Host "  -Disable  Disable Remote Assistance without prompting" -ForegroundColor Cyan
	Write-Host "  -Enable   Enable Remote Assistance without prompting" -ForegroundColor Cyan
	Write-Host "  -Preview  Report current Remote Assistance registry and firewall status without changing anything" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

$raPath = 'HKLM:\System\CurrentControlSet\Control\Remote Assistance'

# -Enable and -Disable are mutually exclusive
if ($Enable -and $Disable) {
	Write-Host ""
	Write-Error "-Enable and -Disable are mutually exclusive."
	exit 1
}

# -Preview reports current status and bypasses the interactive menu entirely
if ($Preview) {
	try {
		$currentValue = if (Test-Path $raPath) { (Get-ItemProperty -Path $raPath -Name "fAllowToGetHelp" -ErrorAction SilentlyContinue).fAllowToGetHelp } else { $null }

		if ($currentValue -eq 1) {
			Write-Host "Remote Assistance registry setting is currently ENABLED."
		}
		else {
			Write-Host "Remote Assistance registry setting is currently DISABLED."
		}

		$fwRules = Get-NetFirewallRule -DisplayGroup "Remote Assistance" -ErrorAction SilentlyContinue
		if ($fwRules) {
			$enabledCount = @($fwRules | Where-Object { $_.Enabled -eq "True" }).Count
			$totalCount = @($fwRules).Count
			Write-Host "Remote Assistance firewall rules: $enabledCount of $totalCount currently enabled."
		}
		else {
			Write-Host "No Remote Assistance firewall rules found."
		}
	}
	catch {
		Write-Host ""
		Write-Error "$ScriptName`: Failed to check Remote Assistance status: $($_.Exception.Message)"
		exit 1
	}

	exit 0
}

# If neither flag is passed, fall through to interactive menu
if (-not $Enable -and -not $Disable) {
	Write-Host "`n1. Enable Remote Assistance"
	Write-Host "2. Disable Remote Assistance"
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
$registryChanged = $false
$firewallChanged = $false

Write-Host "`nChecking Remote Assistance status..." -ForegroundColor Cyan

try {
	if (-not (Test-Path $raPath)) {
		New-Item -Path $raPath -Force | Out-Null
	}

	$currentValue = Get-ItemProperty -Path $raPath -Name "fAllowToGetHelp" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty fAllowToGetHelp

	if ($enabling) {
		if ($currentValue -eq 1) {
			Write-Host ""
			Write-Warning "Remote Assistance is already enabled in the registry."
		}
		else {
			Set-ItemProperty -Path $raPath -Name "fAllowToGetHelp" -Value 1 -Type DWord -ErrorAction Stop
			Write-Host "`nRegistry setting updated." -ForegroundColor Green
			$registryChanged = $true
		}
	}
	else {
		if ($currentValue -eq 0) {
			Write-Host ""
			Write-Warning "Remote Assistance is already disabled in the registry."
		}
		else {
			Set-ItemProperty -Path $raPath -Name "fAllowToGetHelp" -Value 0 -Type DWord -ErrorAction Stop
			Write-Host "`nRegistry setting updated." -ForegroundColor Green
			$registryChanged = $true
		}
	}
}
catch {
	Write-Host ""
	Write-Error "$ScriptName`: Failed to check or modify Remote Assistance registry setting: $($_.Exception.Message)"
	exit 1
}

try {
	$fwRules = Get-NetFirewallRule -DisplayGroup "Remote Assistance" -ErrorAction SilentlyContinue
	if ($fwRules) {
		if ($enabling) {
			$disabledRules = $fwRules | Where-Object { $_.Enabled -eq "False" }
			if ($disabledRules) {
				$disabledRules | Enable-NetFirewallRule -ErrorAction Stop
				Write-Host "`nWindows Firewall rules enabled (Remote Assistance group)." -ForegroundColor Green
				$firewallChanged = $true
			}
			else {
				Write-Host ""
				Write-Warning "Remote Assistance firewall rules are already enabled."
			}
		}
		else {
			$enabledRules = $fwRules | Where-Object { $_.Enabled -eq "True" }
			if ($enabledRules) {
				$enabledRules | Disable-NetFirewallRule -ErrorAction Stop
				Write-Host "`nWindows Firewall rules disabled (Remote Assistance group)." -ForegroundColor Green
				$firewallChanged = $true
			}
			else {
				Write-Host ""
				Write-Warning "Remote Assistance firewall rules are already disabled."
			}
		}
	}
	else {
		Write-Host ""
		Write-Warning "No Remote Assistance firewall rules found."
	}
}
catch {
	Write-Host ""
	Write-Warning "$ScriptName`: Firewall rule modification failed: $($_.Exception.Message)"
}

if ($enabling) {
	if ($registryChanged -or $firewallChanged) {
		Write-Host "`n$ScriptName`: Remote Assistance enabled successfully." -ForegroundColor Green
	}
	else {
		Write-Host ""
		Write-Warning "$ScriptName`: Remote Assistance was already enabled. No changes made."
	}
}
else {
	if ($registryChanged -or $firewallChanged) {
		Write-Host "`n$ScriptName`: Remote Assistance disabled successfully." -ForegroundColor Green
	}
	else {
		Write-Host ""
		Write-Warning "$ScriptName`: Remote Assistance was already disabled. No changes made."
	}
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.