# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script file allows local administrator accounts to perform remote admin tasks without UAC restrictions by enabling LocalAccountTokenFilterPolicy in the Registry

#Requires -RunAsAdministrator

# Enable LocalAccountTokenFilterPolicy
$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

try {
	if (-not (Test-Path $regPath)) {
		New-Item -Path $regPath -Force | Out-Null
	}

	Set-ItemProperty -Path $regPath -Name "LocalAccountTokenFilterPolicy" -Type DWord -Value 1 -Force

	Write-Host "`nLocalAccountTokenFilterPolicy successfully enabled." -ForegroundColor Green
}
catch {
	Write-Host "`nFailed to enable LocalAccountTokenFilterPolicy: $($_.Exception.Message)." -ForegroundColor Red
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.