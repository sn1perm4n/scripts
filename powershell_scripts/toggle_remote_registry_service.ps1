# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script enables or disables the RemoteRegistry service

# Optional flags:
#     -Disable: Disable the RemoteRegistry service without prompting
#     -Enable:  Enable the RemoteRegistry service without prompting
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

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Disable] [-Enable] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Disable  Disable the RemoteRegistry service without prompting" -ForegroundColor Cyan
	Write-Host "  -Enable   Enable the RemoteRegistry service without prompting" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# If neither flag is passed, fall through to interactive menu
if (-not $Enable -and -not $Disable) {
	Write-Host "`n1. Enable RemoteRegistry service"
	Write-Host "2. Disable RemoteRegistry service"
	Write-Host "`nPress 1 or 2 to continue..." -ForegroundColor Cyan

	while ($true) {
		$key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
		if ($key -eq '1' -or $key -eq '2') { break }
		Write-Host "`nInvalid input. Please press 1 or 2..." -ForegroundColor Yellow
	}

	$Enable = $key -eq '1'
	$Disable = $key -eq '2'
}

$enabling = $Enable -eq $true
$serviceName = "RemoteRegistry"
$serviceChanged = $false

Write-Host "`nChecking RemoteRegistry service status..." -ForegroundColor Cyan

$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if (-not $svc) {
	Write-Host "`nService '$serviceName' not found." -ForegroundColor Yellow
	exit 0
}

if ($enabling) {
	# Enable the service (Windows default is Manual)
	if ($svc.StartType -eq 'Manual') {
		Write-Host "`nService '$serviceName' is already enabled." -ForegroundColor Yellow
	}
	else {
		try {
			Set-Service -Name $serviceName -StartupType Manual -ErrorAction Stop
			Write-Host "`nService '$serviceName' startup type successfully set to Manual." -ForegroundColor Green
			$serviceChanged = $true
		}
		catch {
			Write-Host ""
			Write-Warning "Could not enable service '$serviceName': $($_.Exception.Message)"
		}
	}
	# Start the service
	if ($svc.Status -eq 'Running') {
		Write-Host "Service '$serviceName' is already running." -ForegroundColor Yellow
	}
	else {
		try {
			Start-Service -Name $serviceName -ErrorAction Stop
			Write-Host "Service '$serviceName' started successfully." -ForegroundColor Green
			$serviceChanged = $true
		}
		catch {
			Write-Host ""
			Write-Warning "Could not start service '$serviceName': $($_.Exception.Message)"
		}
	}
}
else {
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
}

if ($enabling) {
	if ($serviceChanged) {
		Write-Host "`nRemoteRegistry service successfully enabled and started." -ForegroundColor Green
	}
	else {
		Write-Host "`nRemoteRegistry service was already enabled and running. No changes made." -ForegroundColor Yellow
	}
}
else {
	if ($serviceChanged) {
		Write-Host "`nRemoteRegistry service successfully disabled and stopped." -ForegroundColor Green
	}
	else {
		Write-Host "`nRemoteRegistry service was already disabled and stopped. No changes made." -ForegroundColor Yellow
	}
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.