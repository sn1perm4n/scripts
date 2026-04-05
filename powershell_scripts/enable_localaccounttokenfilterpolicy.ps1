# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script file allows local administrator accounts to perform remote admin tasks without UAC restrictions by enabling LocalAccountTokenFilterPolicy in the Registry

#Requires -RunAsAdministrator

$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

Write-Host "`nChecking LocalAccountTokenFilterPolicy status..." -ForegroundColor Cyan

try {
	if (-not (Test-Path $regPath)) {
		New-Item -Path $regPath -Force | Out-Null
	}

	$currentValue = (Get-ItemProperty -Path $regPath -Name "LocalAccountTokenFilterPolicy" -ErrorAction SilentlyContinue).LocalAccountTokenFilterPolicy

	if ($currentValue -eq 1) {
		Write-Host "`nLocalAccountTokenFilterPolicy is already enabled." -ForegroundColor Yellow
		exit 0
	}

	Set-ItemProperty -Path $regPath -Name "LocalAccountTokenFilterPolicy" -Type DWord -Value 1 -Force -ErrorAction Stop
	Write-Host "`nLocalAccountTokenFilterPolicy successfully enabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Failed to enable LocalAccountTokenFilterPolicy: $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.