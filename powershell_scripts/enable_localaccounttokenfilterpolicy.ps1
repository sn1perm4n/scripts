# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script file allows local administrator accounts to perform remote admin tasks without UAC restrictions by enabling LocalAccountTokenFilterPolicy in the Registry
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

# End.