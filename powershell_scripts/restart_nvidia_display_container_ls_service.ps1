# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script forcefully restarts the Nvidia Display Container LS service (NVDisplay.ContainerLocalSystem)

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

$serviceName = "NVDisplay.ContainerLocalSystem"
$displayName = "Nvidia Display Container LS"

Write-Host "`nChecking $displayName service status..." -ForegroundColor Cyan

$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if (-not $svc) {
	Write-Host ""
	Write-Error "Service '$serviceName' not found. Is the Nvidia driver installed?"
	exit 1
}

# Stop the service if it's currently running
$stopSuccess = $false
if ($svc.Status -eq 'Stopped') {
	Write-Host "`n$displayName is already stopped." -ForegroundColor Yellow
	$stopSuccess = $true
}
else {
	try {
		Stop-Service -Name $serviceName -Force -ErrorAction Stop
		Write-Host "`n$displayName stopped successfully." -ForegroundColor Green
		$stopSuccess = $true
	}
	catch {
		Write-Host ""
		Write-Warning "Could not stop $displayName`: $($_.Exception.Message)"
	}
}

# Start the service
$startSuccess = $false
if ($stopSuccess) {
	try {
		Start-Service -Name $serviceName -ErrorAction Stop
		Write-Host "$displayName started successfully." -ForegroundColor Green
		$startSuccess = $true
	}
	catch {
		Write-Host ""
		Write-Warning "Could not start $displayName`: $($_.Exception.Message)"
	}
}

if ($startSuccess) {
	Write-Host "`n$ScriptName`: $displayName restarted successfully." -ForegroundColor Green
}
else {
	Write-Host "`n$ScriptName`: $displayName restart failed." -ForegroundColor Yellow
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.