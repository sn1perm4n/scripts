# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script stops and disables the Intel Driver and Support Assistant services

#Requires -RunAsAdministrator

$dsaService = "DSAService"
$dsaUpdateService = "DSAUpdateService"

Write-Host "`nChecking Intel Driver and Support Assistant service(s) status..." -ForegroundColor Cyan

# Process DSAService
$svc = Get-Service -Name $dsaService -ErrorAction SilentlyContinue
if (-not $svc) {
	Write-Host "`nService '$dsaService' not found." -ForegroundColor Yellow
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

# Process DSAUpdateService
$svc = Get-Service -Name $dsaUpdateService -ErrorAction SilentlyContinue
if (-not $svc) {
	Write-Host "`nService '$dsaUpdateService' not found." -ForegroundColor Yellow
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

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.