# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script prevents local administrator accounts from performing remote admin tasks without UAC restrictions by disabling LocalAccountTokenFilterPolicy in the Registry

#Requires -RunAsAdministrator

$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

Write-Host "`nChecking LocalAccountTokenFilterPolicy status..." -ForegroundColor Cyan

try {
	if (-not (Test-Path $regPath)) {
		New-Item -Path $regPath -Force | Out-Null
	}

	$currentValue = (Get-ItemProperty -Path $regPath -Name "LocalAccountTokenFilterPolicy" -ErrorAction SilentlyContinue).LocalAccountTokenFilterPolicy

	if ($currentValue -eq 0 -or $null -eq $currentValue) {
		Write-Host ""
		Write-Warning "LocalAccountTokenFilterPolicy is already disabled."
		exit 0
	}

	Set-ItemProperty -Path $regPath -Name "LocalAccountTokenFilterPolicy" -Type DWord -Value 0 -Force -ErrorAction Stop
	Write-Host "`n$ScriptName`: LocalAccountTokenFilterPolicy disabled successfully." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Error "$ScriptName`: Failed to disable LocalAccountTokenFilterPolicy: $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.