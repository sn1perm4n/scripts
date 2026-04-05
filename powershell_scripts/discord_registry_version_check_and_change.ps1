# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# Script to query and change the Discord DisplayVersion Registry value based on user input. Check what the version number says within the Discord's settings and then change it match within the Registry.
# Reads (and changes) this value: HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Discord\DisplayVersion

# NOTE: This script is no longer relevant as it appears Discord FINALLY fixed the bug in question. The entire reason I wrote this script was because the Discord installer/updater wasn't updating its own version number in the Windows registry, which then made winget (and likely other software update checkers) think it was always out of date. I'm going to keep this script on Github for learning purposes.

# Registry path
$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Discord"

# Property name
$propertyName = "DisplayVersion"

# Check if the registry path exists
if (-not (Test-Path $registryPath)) {
	Write-Host "Error: The specified Registry path does not exist."
	exit
}

# Get the current DisplayVersion value
try {
	$currentValue = (Get-ItemProperty -Path $registryPath -Name $propertyName).$propertyName
	Write-Host "Current value of '$propertyName' at '$registryPath': $currentValue"
	# Read-Host # Uncomment to see DisplayVersion value
}
catch {
	Write-Host "Error: Could not retrieve the current value. Ensure the property name is correct."
	exit
}

# Prompt for the new DisplayVersion value
$newValue = Read-Host -Prompt "Enter the new value for '$propertyName'"

# Change the Registry value
try {
	Set-ItemProperty -Path $registryPath -Name $propertyName -Value $newValue -Force
	Write-Host "Registry value '$propertyName' at '$registryPath' successfully updated to '$newValue'."
}
catch {
	Write-Host "Error: Could not update the Registry value. Ensure you have the necessary permissions."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.