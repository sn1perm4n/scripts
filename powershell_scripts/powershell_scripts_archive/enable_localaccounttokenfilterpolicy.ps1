# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script allows local administrator accounts to perform remote admin tasks without UAC restrictions by enabling LocalAccountTokenFilterPolicy in the Registry

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

	if ($currentValue -eq 1) {
		Write-Host ""
		Write-Warning "LocalAccountTokenFilterPolicy is already enabled."
		exit 0
	}

	Set-ItemProperty -Path $regPath -Name "LocalAccountTokenFilterPolicy" -Type DWord -Value 1 -Force -ErrorAction Stop
	Write-Host "`n$ScriptName`: LocalAccountTokenFilterPolicy enabled successfully." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Error "$ScriptName`: Failed to enable LocalAccountTokenFilterPolicy: $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.