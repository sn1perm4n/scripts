# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables and stops the RemoteRegistry service

#Requires -RunAsAdministrator

$serviceName = "RemoteRegistry"

Write-Host "`nChecking RemoteRegistry service status..." -ForegroundColor Cyan

$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if (-not $svc) {
	Write-Host "`nService '$serviceName' not found." -ForegroundColor Yellow
	exit 0
}

$serviceChanged = $false

# Disable the service
if ($svc.StartType -eq 'Disabled') {
	Write-Host "`nService '$serviceName' is already disabled." -ForegroundColor Yellow
}
else {
	try {
		Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
		Write-Host "`nService '$serviceName' startup type successfully set to Disabled." -ForegroundColor Green
		$serviceChanged = $true
	}
	catch {
		Write-Host ""
		Write-Warning "Could not disable service '$serviceName': $($_.Exception.Message)"
	}
}

# Stop the service if it's currently running
if ($svc.Status -eq 'Stopped') {
	Write-Host "Service '$serviceName' is already stopped." -ForegroundColor Yellow
}
else {
	try {
		Stop-Service -Name $serviceName -Force -ErrorAction Stop
		Write-Host "Service '$serviceName' stopped successfully." -ForegroundColor Green
		$serviceChanged = $true
	}
	catch {
		Write-Host ""
		Write-Warning "Could not stop service '$serviceName': $($_.Exception.Message)"
	}
}

if ($serviceChanged) {
	Write-Host "`nRemoteRegistry service successfully disabled and stopped." -ForegroundColor Green
}
else {
	Write-Host "`nRemoteRegistry service was already disabled and stopped. No changes made." -ForegroundColor Yellow
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.