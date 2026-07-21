# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script updates the winget source database and then runs the upgrade command so potential updates can be seen
# Individual packages can be upgraded via their ID, i.e.: "winget upgrade Microsoft.VCRedist.2013.x86"
# If you want to upgrade everything, you can run "winget upgrade --all"
# Available commands: https://learn.microsoft.com/en-us/windows/package-manager/winget/upgrade
# winget pin add --id <APP_ID> - Disables version checking for said app (useful if you need to avoid upgrading specific applications)
# winget pin remove --id <APP_ID> - Removes a pinned app from winget
# winget pin list - Shows the current pinned app list

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

$hadWarnings = $false

# Update source database
Write-Host "`nUpdating winget source database..." -ForegroundColor Cyan
try {
	winget source update --disable-interactivity
	if ($LASTEXITCODE -ne 0) {
		throw "winget exited with code $LASTEXITCODE."
	}
}
catch {
	Write-Host ""
	Write-Warning "Failed to update winget source database: $($_.Exception.Message)"
	$hadWarnings = $true
}

# Show programs that need updating
Write-Host "`nChecking for available upgrades..." -ForegroundColor Cyan
try {
	winget upgrade --accept-source-agreements --disable-interactivity
	if ($LASTEXITCODE -ne 0) {
		throw "winget exited with code $LASTEXITCODE."
	}
}
catch {
	Write-Host ""
	Write-Warning "Failed to retrieve upgrade list: $($_.Exception.Message)"
	$hadWarnings = $true
}

if ($hadWarnings) {
	Write-Host ""
	Write-Warning "$ScriptName`: Completed with warnings."
	exit 1
}
else {
	Write-Host "`n$ScriptName`: Completed successfully." -ForegroundColor Green
	exit 0
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.