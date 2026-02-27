# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables Remote Assistance
#Requires -RunAsAdministrator

# Ensure script runs as Administrator
$principal = New-Object Security.Principal.WindowsPrincipal `
	([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
	Write-Error "This script must be run as Administrator."
	exit 1
}

Write-Host "Disabling Remote Assistance..." -ForegroundColor Cyan

try {
	$raPath = 'HKLM:\System\CurrentControlSet\Control\Remote Assistance'

	# Check current registry value
	$currentValue = Get-ItemProperty -Path $raPath -Name "fAllowToGetHelp" -ErrorAction Stop | Select-Object -ExpandProperty fAllowToGetHelp

	if ($currentValue -eq 0) {
		Write-Host "Remote Assistance is already disabled in the registry." -ForegroundColor Yellow
	} else {
		Set-ItemProperty -Path $raPath -Name "fAllowToGetHelp" -Value 0 -Type DWord -ErrorAction Stop
		Write-Host "Registry setting updated." -ForegroundColor Green
	}
}
catch {
	Write-Error "Failed to check or modify Remote Assistance registry setting: $_"
	exit 1
}

try {
	# Disable Firewall Rules
	$fwRules = Get-NetFirewallRule -DisplayGroup "Remote Assistance" -ErrorAction SilentlyContinue

	if ($fwRules) {
		$enabledRules = $fwRules | Where-Object { $_.Enabled -eq "True" }
		if ($enabledRules) {
			$enabledRules | Disable-NetFirewallRule -ErrorAction Stop
			Write-Host "Windows Firewall rules disabled (Remote Assistance group)." -ForegroundColor Green
		} else {
			Write-Host "Remote Assistance firewall rules are already disabled." -ForegroundColor Yellow
		}
	} else {
		Write-Host "No Remote Assistance firewall rules found." -ForegroundColor Yellow
	}
}
catch {
	Write-Warning "Firewall rule modification failed: $_"
}

Write-Host "`nRemote Assistance has been successfully disabled." -ForegroundColor Green

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.