# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables and stops the RemoteRegistry service

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

$serviceName = "RemoteRegistry"

Write-Host "`nChecking RemoteRegistry service status..." -ForegroundColor Cyan

$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if (-not $svc) {
	Write-Host ""
	Write-Warning "Service '$serviceName' not found."
	exit 0
}

$serviceChanged = $false

# Disable the service
if ($svc.StartType -eq 'Disabled') {
	Write-Host ""
	Write-Warning "Service '$serviceName' is already disabled."
}
else {
	try {
		Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
		Write-Host "`nService '$serviceName' startup type set to Disabled successfully." -ForegroundColor Green
		$serviceChanged = $true
	}
	catch {
		Write-Host ""
		Write-Warning "$ScriptName`: Could not disable service '$serviceName': $($_.Exception.Message)"
	}
}

# Stop the service if it's currently running
if ($svc.Status -eq 'Stopped') {
	Write-Host ""
	Write-Warning "Service '$serviceName' is already stopped."
}
else {
	try {
		Stop-Service -Name $serviceName -Force -ErrorAction Stop
		Write-Host "Service '$serviceName' stopped successfully." -ForegroundColor Green
		$serviceChanged = $true
	}
	catch {
		Write-Host ""
		Write-Warning "$ScriptName`: Could not stop service '$serviceName': $($_.Exception.Message)"
	}
}

if ($serviceChanged) {
	Write-Host "`n$ScriptName`: RemoteRegistry service disabled and stopped successfully." -ForegroundColor Green
}
else {
	Write-Host ""
	Write-Warning "$ScriptName`: RemoteRegistry service was already disabled and stopped. No changes made."
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.