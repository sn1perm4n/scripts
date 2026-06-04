# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script stops and disables the DiagTrack service (otherwise known as "Connected User Experiences and Telemetry")

#Requires -RunAsAdministrator

$serviceName = "DiagTrack"

# Stop the service
try {
	$svc = Get-Service -Name $serviceName -ErrorAction Stop

	if ($svc.Status -eq 'Stopped') {
		Write-Host "Service '$serviceName' is already stopped." -ForegroundColor Yellow
	}
	else {
		Stop-Service -Name $serviceName -Force -ErrorAction Stop
		Write-Host "Service '$serviceName' stopped successfully." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	Write-Warning "Could not stop service '$serviceName': $($_.Exception.Message)"
}

# Disable the service startup type
try {
	$svc = Get-Service -Name $serviceName -ErrorAction Stop

	if ($svc.StartType -eq 'Disabled') {
		Write-Host "Service '$serviceName' startup type is already set to Disabled." -ForegroundColor Yellow
	}
	else {
		Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
		Write-Host "Service '$serviceName' startup type successfully set to Disabled." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	Write-Warning "Could not set startup type for service '$serviceName': $($_.Exception.Message)"
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.