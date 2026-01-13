# This script enables the following in Windows Update:
# 1. Get the latest updates as soon as they're available
# 2. Windows Update -> Advanced options -> Receive updates for other Microsoft products
#Requires -RunAsAdministrator

# Ensure script runs as Administrator
$principal = New-Object Security.Principal.WindowsPrincipal `
	([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $principal.IsInRole(
	[Security.Principal.WindowsBuiltInRole]::Administrator
)) {
	Write-Host "Please run this script as Administrator. Press any key to exit..." -ForegroundColor Red
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit 1
}

Write-Host "Configuring Windows Update..." -ForegroundColor Cyan

$regPath = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'

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
	Write-Error "An error occurred: $($_.Exception.Message)."
	exit 1
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.