# This script enables dark mode in Windows 10 and 11 (activation not required)

# Enable Dark Mode for Windows 10 and 11 (Apps + System)
$regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

try {
	if (-not (Test-Path $regPath)) {
		New-Item -Path $regPath -Force | Out-Null
	}

	Set-ItemProperty -Path $regPath -Name "AppsUseLightTheme" -Type DWord -Value 0 -Force
	Set-ItemProperty -Path $regPath -Name "SystemUsesLightTheme" -Type DWord -Value 0 -Force

	Write-Host "`nDark mode successfully enabled." -ForegroundColor Green
}
catch {
	Write-Host "`nFailed to enable dark mode: $($_.Exception.Message)." -ForegroundColor Red
}

# End.