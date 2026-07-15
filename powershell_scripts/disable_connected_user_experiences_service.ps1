# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script stops and disables the Connected User Experiences and Telemetry service (DiagTrack)

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

$serviceName = "DiagTrack"
$displayName = "Connected User Experiences and Telemetry"
$changesMade = $false

Write-Host "`nChecking $displayName service status..." -ForegroundColor Cyan

$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if (-not $svc) {
	Write-Host ""
	Write-Error "Service '$serviceName' not found."
	exit 1
}

# Disable the service
if ($svc.StartType -eq 'Disabled') {
	Write-Host "`nService '$serviceName' is already disabled." -ForegroundColor Yellow
}
else {
	try {
		Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
		Write-Host "`nService '$serviceName' startup type successfully set to Disabled." -ForegroundColor Green
		$changesMade = $true
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
		$changesMade = $true
	}
	catch {
		Write-Host ""
		Write-Warning "Could not stop service '$serviceName': $($_.Exception.Message)"
	}
}

if ($changesMade) {
	Write-Host "`n$ScriptName`: $displayName service successfully disabled and stopped." -ForegroundColor Green
}
else {
	Write-Host "`n$ScriptName`: $displayName service was already disabled and stopped. No changes made." -ForegroundColor Yellow
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.