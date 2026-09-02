# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script enables or disables the Intel Driver and Support Assistant (DSA) services

# Optional flags:
#     -Disable:   Disable the Intel DSA services without prompting
#     -Enable:    Enable the Intel DSA services without prompting
#     -Preview:   Report current status of the Intel DSA services without changing anything
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
	Write-Host "  -Disable  Disable the Intel DSA services without prompting" -ForegroundColor Cyan
	Write-Host "  -Enable   Enable the Intel DSA services without prompting" -ForegroundColor Cyan
	Write-Host "  -Preview  Report current status of the Intel DSA services without changing anything" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

$dsaService = "DSAService"
$dsaUpdateService = "DSAUpdateService"

# -Enable and -Disable are mutually exclusive
if ($Enable -and $Disable) {
	Write-Host ""
	Write-Error "-Enable and -Disable are mutually exclusive."
	exit 1
}

# -Preview reports current status and bypasses the interactive menu entirely
if ($Preview) {
	foreach ($serviceName in @($dsaService, $dsaUpdateService)) {
		$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
		if (-not $svc) {
			Write-Host "Service '$serviceName': NOT FOUND"
		}
		else {
			Write-Host "Service '$serviceName': StartType=$($svc.StartType), Status=$($svc.Status)"
		}
	}
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
		Write-Host ""
		Write-Warning "Invalid input. Please press 1 or 2..."
	}

	$Enable = $key -eq '1'
	$Disable = $key -eq '2'
}

$enabling = $Enable -eq $true
$changesMade = $false

Write-Host "`nChecking Intel DSA service(s) status..." -ForegroundColor Cyan

# Process DSAService
$svc = Get-Service -Name $dsaService -ErrorAction SilentlyContinue
if (-not $svc) {
	Write-Host ""
	Write-Warning "Service '$dsaService' not found."
}
else {
	if ($enabling) {
		# Enable DSAService
		if ($svc.StartType -eq 'Automatic') {
			Write-Host ""
			Write-Warning "Service '$dsaService' is already enabled."
		}
		else {
			try {
				Set-Service -Name $dsaService -StartupType Automatic -ErrorAction Stop
				Write-Host "`nService '$dsaService' startup type set to Automatic successfully." -ForegroundColor Green
				$changesMade = $true
			}
			catch {
				Write-Host ""
				Write-Warning "$ScriptName`: Could not enable service '$dsaService': $($_.Exception.Message)"
			}
		}
		# Start DSAService
		if ($svc.Status -eq 'Running') {
			Write-Host ""
			Write-Warning "Service '$dsaService' is already running."
		}
		else {
			try {
				Start-Service -Name $dsaService -ErrorAction Stop
				Write-Host "Service '$dsaService' started successfully." -ForegroundColor Green
				$changesMade = $true
			}
			catch {
				Write-Host ""
				Write-Warning "$ScriptName`: Could not start service '$dsaService': $($_.Exception.Message)"
			}
		}
	}
	else {
		# Disable DSAService
		if ($svc.StartType -eq 'Disabled') {
			Write-Host ""
			Write-Warning "Service '$dsaService' is already disabled."
		}
		else {
			try {
				Set-Service -Name $dsaService -StartupType Disabled -ErrorAction Stop
				Write-Host "`nService '$dsaService' startup type set to Disabled successfully." -ForegroundColor Green
				$changesMade = $true
			}
			catch {
				Write-Host ""
				Write-Warning "$ScriptName`: Could not disable service '$dsaService': $($_.Exception.Message)"
			}
		}
		# Stop DSAService
		if ($svc.Status -eq 'Stopped') {
			Write-Host ""
			Write-Warning "Service '$dsaService' is already stopped."
		}
		else {
			try {
				Stop-Service -Name $dsaService -Force -ErrorAction Stop
				Write-Host "Service '$dsaService' stopped successfully." -ForegroundColor Green
				$changesMade = $true
			}
			catch {
				Write-Host ""
				Write-Warning "$ScriptName`: Could not stop service '$dsaService': $($_.Exception.Message)"
			}
		}
	}
}

# Process DSAUpdateService
$svc = Get-Service -Name $dsaUpdateService -ErrorAction SilentlyContinue
if (-not $svc) {
	Write-Host ""
	Write-Warning "Service '$dsaUpdateService' not found."
}
else {
	if ($enabling) {
		# Enable DSAUpdateService
		if ($svc.StartType -eq 'Automatic') {
			Write-Host ""
			Write-Warning "Service '$dsaUpdateService' is already enabled."
		}
		else {
			try {
				Set-Service -Name $dsaUpdateService -StartupType Automatic -ErrorAction Stop
				Write-Host "`nService '$dsaUpdateService' startup type set to Automatic successfully." -ForegroundColor Green
				$changesMade = $true
			}
			catch {
				Write-Host ""
				Write-Warning "$ScriptName`: Could not enable service '$dsaUpdateService': $($_.Exception.Message)"
			}
		}
		# Start DSAUpdateService
		if ($svc.Status -eq 'Running') {
			Write-Host ""
			Write-Warning "Service '$dsaUpdateService' is already running."
		}
		else {
			try {
				Start-Service -Name $dsaUpdateService -ErrorAction Stop
				Write-Host "Service '$dsaUpdateService' started successfully." -ForegroundColor Green
				$changesMade = $true
			}
			catch {
				Write-Host ""
				Write-Warning "$ScriptName`: Could not start service '$dsaUpdateService': $($_.Exception.Message)"
			}
		}
	}
	else {
		# Disable DSAUpdateService
		if ($svc.StartType -eq 'Disabled') {
			Write-Host ""
			Write-Warning "Service '$dsaUpdateService' is already disabled."
		}
		else {
			try {
				Set-Service -Name $dsaUpdateService -StartupType Disabled -ErrorAction Stop
				Write-Host "`nService '$dsaUpdateService' startup type set to Disabled successfully." -ForegroundColor Green
				$changesMade = $true
			}
			catch {
				Write-Host ""
				Write-Warning "$ScriptName`: Could not disable service '$dsaUpdateService': $($_.Exception.Message)"
			}
		}
		# Stop DSAUpdateService
		if ($svc.Status -eq 'Stopped') {
			Write-Host ""
			Write-Warning "Service '$dsaUpdateService' is already stopped."
		}
		else {
			try {
				Stop-Service -Name $dsaUpdateService -Force -ErrorAction Stop
				Write-Host "Service '$dsaUpdateService' stopped successfully." -ForegroundColor Green
				$changesMade = $true
			}
			catch {
				Write-Host ""
				Write-Warning "$ScriptName`: Could not stop service '$dsaUpdateService': $($_.Exception.Message)"
			}
		}
	}
}

if ($enabling) {
	if ($changesMade) {
		Write-Host "`n$ScriptName`: Intel DSA services enabled successfully." -ForegroundColor Green
	}
	else {
		Write-Host ""
		Write-Warning "$ScriptName`: Intel DSA services were already enabled. No changes made."
	}
}
else {
	if ($changesMade) {
		Write-Host "`n$ScriptName`: Intel DSA services disabled successfully." -ForegroundColor Green
	}
	else {
		Write-Host ""
		Write-Warning "$ScriptName`: Intel DSA services were already disabled. No changes made."
	}
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.