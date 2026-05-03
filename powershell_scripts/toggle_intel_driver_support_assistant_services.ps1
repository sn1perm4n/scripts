# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script enables or disables the Intel Driver and Support Assistant services

# Optional flags:
#     -Disable: Disable the Intel DSA services without prompting
#     -Enable:  Enable the Intel DSA services without prompting
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
	Write-Host "  -Disable  Disable the Intel DSA services without prompting" -ForegroundColor Cyan
	Write-Host "  -Enable   Enable the Intel DSA services without prompting" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# If neither flag is passed, fall through to interactive menu
if (-not $Enable -and -not $Disable) {
	Write-Host "`n1. Enable Intel DSA services"
	Write-Host "2. Disable Intel DSA services"
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
$dsaService = "DSAService"
$dsaUpdateService = "DSAUpdateService"

Write-Host "`nChecking Intel Driver and Support Assistant service(s) status..." -ForegroundColor Cyan

# Process DSAService
$svc = Get-Service -Name $dsaService -ErrorAction SilentlyContinue
if (-not $svc) {
	Write-Host "`nService '$dsaService' not found." -ForegroundColor Yellow
}
else {
	if ($enabling) {
		# Enable DSAService
		if ($svc.StartType -eq 'Automatic') {
			Write-Host "`nService '$dsaService' is already enabled." -ForegroundColor Yellow
		}
		else {
			try {
				Set-Service -Name $dsaService -StartupType Automatic -ErrorAction Stop
				Write-Host "`nService '$dsaService' startup type successfully set to Automatic." -ForegroundColor Green
			}
			catch {
				Write-Host ""
				Write-Warning "Could not enable service '$dsaService': $($_.Exception.Message)"
			}
		}
		# Start DSAService
		if ($svc.Status -eq 'Running') {
			Write-Host "Service '$dsaService' is already running." -ForegroundColor Yellow
		}
		else {
			try {
				Start-Service -Name $dsaService -ErrorAction Stop
				Write-Host "Service '$dsaService' started successfully." -ForegroundColor Green
			}
			catch {
				Write-Host ""
				Write-Warning "Could not start service '$dsaService': $($_.Exception.Message)"
			}
		}
	}
	else {
		# Disable DSAService
		if ($svc.StartType -eq 'Disabled') {
			Write-Host "`nService '$dsaService' is already disabled." -ForegroundColor Yellow
		}
		else {
			try {
				Set-Service -Name $dsaService -StartupType Disabled -ErrorAction Stop
				Write-Host "`nService '$dsaService' startup type successfully set to Disabled." -ForegroundColor Green
			}
			catch {
				Write-Host ""
				Write-Warning "Could not disable service '$dsaService': $($_.Exception.Message)"
			}
		}
		# Stop DSAService
		if ($svc.Status -eq 'Stopped') {
			Write-Host "Service '$dsaService' is already stopped." -ForegroundColor Yellow
		}
		else {
			try {
				Stop-Service -Name $dsaService -Force -ErrorAction Stop
				Write-Host "Service '$dsaService' stopped successfully." -ForegroundColor Green
			}
			catch {
				Write-Host ""
				Write-Warning "Could not stop service '$dsaService': $($_.Exception.Message)"
			}
		}
	}
}

# Process DSAUpdateService
$svc = Get-Service -Name $dsaUpdateService -ErrorAction SilentlyContinue
if (-not $svc) {
	Write-Host "`nService '$dsaUpdateService' not found." -ForegroundColor Yellow
}
else {
	if ($enabling) {
		# Enable DSAUpdateService
		if ($svc.StartType -eq 'Automatic') {
			Write-Host "`nService '$dsaUpdateService' is already enabled." -ForegroundColor Yellow
		}
		else {
			try {
				Set-Service -Name $dsaUpdateService -StartupType Automatic -ErrorAction Stop
				Write-Host "`nService '$dsaUpdateService' startup type successfully set to Automatic." -ForegroundColor Green
			}
			catch {
				Write-Host ""
				Write-Warning "Could not enable service '$dsaUpdateService': $($_.Exception.Message)"
			}
		}
		# Start DSAUpdateService
		if ($svc.Status -eq 'Running') {
			Write-Host "Service '$dsaUpdateService' is already running." -ForegroundColor Yellow
		}
		else {
			try {
				Start-Service -Name $dsaUpdateService -ErrorAction Stop
				Write-Host "Service '$dsaUpdateService' started successfully." -ForegroundColor Green
			}
			catch {
				Write-Host ""
				Write-Warning "Could not start service '$dsaUpdateService': $($_.Exception.Message)"
			}
		}
	}
	else {
		# Disable DSAUpdateService
		if ($svc.StartType -eq 'Disabled') {
			Write-Host "`nService '$dsaUpdateService' is already disabled." -ForegroundColor Yellow
		}
		else {
			try {
				Set-Service -Name $dsaUpdateService -StartupType Disabled -ErrorAction Stop
				Write-Host "`nService '$dsaUpdateService' startup type successfully set to Disabled." -ForegroundColor Green
			}
			catch {
				Write-Host ""
				Write-Warning "Could not disable service '$dsaUpdateService': $($_.Exception.Message)"
			}
		}
		# Stop DSAUpdateService
		if ($svc.Status -eq 'Stopped') {
			Write-Host "Service '$dsaUpdateService' is already stopped." -ForegroundColor Yellow
		}
		else {
			try {
				Stop-Service -Name $dsaUpdateService -Force -ErrorAction Stop
				Write-Host "Service '$dsaUpdateService' stopped successfully." -ForegroundColor Green
			}
			catch {
				Write-Host ""
				Write-Warning "Could not stop service '$dsaUpdateService': $($_.Exception.Message)"
			}
		}
	}
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.