# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script enables the following settings in Windows Update:
# 1. Get the latest updates as soon as they're available
# 2. Windows Update -> Advanced options -> Receive updates for other Microsoft products

#Requires -RunAsAdministrator

$regPath = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'

Write-Host "`nConfiguring Windows Update..." -ForegroundColor Cyan

# Configure Windows Update via Registry changes
try {
	if (-not (Test-Path $regPath)) {
		New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null
	}

	if (-not (Get-ItemProperty -Path $regPath -Name "IsContinuousInnovationOptedIn" -ErrorAction SilentlyContinue)) {
		New-ItemProperty -Path $regPath -Name "IsContinuousInnovationOptedIn" -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null
	}
	else {
		Set-ItemProperty -Path $regPath -Name "IsContinuousInnovationOptedIn" -Value 1 -Force -ErrorAction Stop
	}

	if (-not (Get-ItemProperty -Path $regPath -Name "AllowMUUpdateService" -ErrorAction SilentlyContinue)) {
		New-ItemProperty -Path $regPath -Name "AllowMUUpdateService" -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null
	}
	else {
		Set-ItemProperty -Path $regPath -Name "AllowMUUpdateService" -Value 1 -Force -ErrorAction Stop
	}

	Write-Host "`nWindows Update has been configured." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Error "An error occurred: $($_.Exception.Message)"
	exit 1
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.