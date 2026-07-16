# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables Remote Assistance

#Requires -RunAsAdministrator

$raPath = 'HKLM:\System\CurrentControlSet\Control\Remote Assistance'
$registryChanged = $false
$firewallChanged = $false

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

Write-Host "`nChecking Remote Assistance status..." -ForegroundColor Cyan

try {
	# Check current registry value
	$currentValue = Get-ItemProperty -Path $raPath -Name "fAllowToGetHelp" -ErrorAction Stop | Select-Object -ExpandProperty fAllowToGetHelp

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
catch {
	Write-Host ""
	Write-Error "$ScriptName`: Failed to check or modify Remote Assistance registry setting: $($_.Exception.Message)"
	exit 1
}

try {
	# Disable Firewall Rules
	$fwRules = Get-NetFirewallRule -DisplayGroup "Remote Assistance" -ErrorAction SilentlyContinue

	if ($fwRules) {
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
	else {
		Write-Host ""
		Write-Warning "No Remote Assistance firewall rules found."
	}
}
catch {
	Write-Host ""
	Write-Warning "$ScriptName`: Firewall rule modification failed: $($_.Exception.Message)"
}

if ($registryChanged -or $firewallChanged) {
	Write-Host "`n$ScriptName`: Remote Assistance disabled successfully." -ForegroundColor Green
}
else {
	Write-Host ""
	Write-Warning "$ScriptName`: Remote Assistance was already disabled. No changes made."
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.