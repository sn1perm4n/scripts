# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables dark mode in Windows 10 and 11 (activation not required)

$regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

Write-Host "`nChecking dark mode status..." -ForegroundColor Cyan

try {
	if (-not (Test-Path $regPath)) {
		New-Item -Path $regPath -Force | Out-Null
	}

	$props = Get-ItemProperty -Path $regPath -ErrorAction Stop
	$appsLight = $props.AppsUseLightTheme
	$systemLight = $props.SystemUsesLightTheme

	if ($appsLight -eq 1 -and $systemLight -eq 1) {
		Write-Host "`nDark mode is already disabled." -ForegroundColor Yellow
		exit 0
	}

	Set-ItemProperty -Path $regPath -Name "AppsUseLightTheme" -Type DWord -Value 1 -Force -ErrorAction Stop
	Set-ItemProperty -Path $regPath -Name "SystemUsesLightTheme" -Type DWord -Value 1 -Force -ErrorAction Stop
	Write-Host "`nDark mode successfully disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Error "Failed to disable dark mode: $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.