# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script rebuilds the Windows icon cache to fix missing or corrupted icons. It safely stops File Explorer, removes all IconCache database files, clears the thumbnail cache, and notifies the user to reboot.

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

# Stop File Explorer
try {
	Write-Host "`nStopping File Explorer..." -ForegroundColor Cyan
	Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
	Start-Sleep -Seconds 2
}
catch {
	Write-Error "Failed to stop File Explorer: $($_.Exception.Message)"
	exit 1
}

# Delete icon cache files
Write-Host "`nRemoving icon cache files..." -ForegroundColor Cyan

$cachePaths = @(
	"$env:LOCALAPPDATA\IconCache.db",
	"$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*.db",
	"$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache*.db"
)

foreach ($pattern in $cachePaths) {
	$files = Get-Item -Path $pattern -ErrorAction SilentlyContinue
	if (-not $files) {
		Write-Warning "No files matched: $pattern"
		continue
	}
	foreach ($file in $files) {
		try {
			Remove-Item -Path $file.FullName -Force -ErrorAction Stop
			Write-Host "  Deleted: $($file.Name)" -ForegroundColor Green
		}
		catch {
			Write-Warning "Could not delete $($file.Name): $($_.Exception.Message)"
		}
	}
}

Write-Host "`nIconCache rebuild complete. Please reboot for changes to take effect." -ForegroundColor Green

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.