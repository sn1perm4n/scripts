# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# Script to query and change the Discord DisplayVersion Registry value based on user input. Check what the version number says within the Discord's settings and then change it match within the Registry.
# Reads (and changes) this value: HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Discord\DisplayVersion

# NOTE: This script is no longer relevant as it appears Discord FINALLY fixed the bug in question. The entire reason I wrote this script was because the Discord installer/updater wasn't updating its own version number in the Windows registry, which then made winget (and likely other software update checkers) think it was always out of date. I'm going to keep this script on Github for learning purposes.

$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Discord"
$propertyName = "DisplayVersion"

# Check if the registry path exists
if (-not (Test-Path $registryPath)) {
	Write-Error "The specified Registry path does not exist: '$registryPath'"
	exit 1
}

# Get the current DisplayVersion value
try {
	$currentValue = (Get-ItemProperty -Path $registryPath -Name $propertyName -ErrorAction Stop).$propertyName
	Write-Host "`nCurrent value of '$propertyName' at '$registryPath': $currentValue" -ForegroundColor Cyan
}
catch {
	Write-Error "Could not retrieve the current value: $($_.Exception.Message)"
	exit 1
}

# Prompt for the new DisplayVersion value
$newValue = Read-Host -Prompt "`nEnter the new value for '$propertyName'"

# Change the Registry value
try {
	Set-ItemProperty -Path $registryPath -Name $propertyName -Value $newValue -Force -ErrorAction Stop
	Write-Host "`nRegistry value '$propertyName' successfully updated to '$newValue'." -ForegroundColor Green
}
catch {
	Write-Error "Could not update the Registry value: $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.