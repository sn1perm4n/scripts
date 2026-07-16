# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script stops and disables the Intel Driver and Support Assistant services

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

$dsaService = "DSAService"
$dsaUpdateService = "DSAUpdateService"
$changesMade = $false

Write-Host "`nChecking Intel Driver and Support Assistant service(s) status..." -ForegroundColor Cyan

# Process DSAService
$svc = Get-Service -Name $dsaService -ErrorAction SilentlyContinue
if (-not $svc) {
	Write-Host ""
	Write-Warning "Service '$dsaService' not found."
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

# Process DSAUpdateService
$svc = Get-Service -Name $dsaUpdateService -ErrorAction SilentlyContinue
if (-not $svc) {
	Write-Host ""
	Write-Warning "Service '$dsaUpdateService' not found."
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

if ($changesMade) {
	Write-Host "`n$ScriptName`: Intel DSA services disabled and stopped successfully." -ForegroundColor Green
}
else {
	Write-Host ""
	Write-Warning "$ScriptName`: Intel DSA services were already disabled and stopped. No changes made."
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.