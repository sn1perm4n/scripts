# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script hides hidden files and folders by making Registry changes and refreshing File Explorer to make the changes active

$registryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

Write-Host "`nChecking hidden files and folders visibility status..." -ForegroundColor Cyan

try {
	$props = Get-ItemProperty -Path $registryPath -ErrorAction Stop
	$hidden = $props.Hidden
	$showSuperHidden = $props.ShowSuperHidden

	if ($hidden -eq 0 -and $showSuperHidden -eq 0) {
		Write-Host ""
		Write-Warning "Hidden files and folders are already hidden."
		exit 0
	}

	Set-ItemProperty -Path $registryPath -Name Hidden -Type DWord -Value 0 -Force -ErrorAction Stop
	Set-ItemProperty -Path $registryPath -Name ShowSuperHidden -Type DWord -Value 0 -Force -ErrorAction Stop

	# Refresh File Explorer to apply changes immediately
	$shell = New-Object -ComObject Shell.Application
	$shell.Windows() | ForEach-Object { $_.Refresh() }

	Write-Host "`n$ScriptName`: Hidden files and folders hidden successfully." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Error "$ScriptName`: Failed to hide hidden files and folders: $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.