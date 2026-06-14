# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script updates the Mozilla Maintenance Service by running maintenanceservice_installer.exe from the Firefox installation directory

# NOTE: This script supports both 64-bit and 32-bit Firefox installations and will use whichever is found on disk

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

$installer64 = "C:\Program Files\Mozilla Firefox\maintenanceservice_installer.exe"
$installer32 = "C:\Program Files (x86)\Mozilla Firefox\maintenanceservice_installer.exe"

$installerPath = if (Test-Path $installer64) { $installer64 }
elseif (Test-Path $installer32) { $installer32 }
else { $null }

if (-not $installerPath) {
	Write-Host ""
	Write-Error "Mozilla Maintenance Service installer not found. Is Firefox installed?"
	exit 1
}

Write-Host "`nFound installer at: $installerPath" -ForegroundColor Cyan
Write-Host "Running Mozilla Maintenance Service installer..." -ForegroundColor Cyan

try {
	$process = Start-Process -FilePath $installerPath -Wait -PassThru -ErrorAction Stop
	if ($process.ExitCode -eq 0) {
		Write-Host "`n$ScriptName`: Mozilla Maintenance Service updated successfully." -ForegroundColor Green
	}
	else {
		Write-Host "`n$ScriptName`: Installer exited with code $($process.ExitCode)." -ForegroundColor Yellow
	}
}
catch {
	Write-Host ""
	Write-Error "Failed to run installer: $($_.Exception.Message)"
	exit 1
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.