# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script starts the Intel Driver and Support Assistant services

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
	# Enable DSAService
	if ($svc.StartType -eq 'Automatic') {
		Write-Host "`nService '$dsaService' is already set to Automatic." -ForegroundColor Yellow
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

# Process DSAUpdateService
$svc = Get-Service -Name $dsaUpdateService -ErrorAction SilentlyContinue
if (-not $svc) {
	Write-Host "`nService '$dsaUpdateService' not found." -ForegroundColor Yellow
}
else {
	# Enable DSAUpdateService
	if ($svc.StartType -eq 'Automatic') {
		Write-Host "`nService '$dsaUpdateService' is already set to Automatic." -ForegroundColor Yellow
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

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.