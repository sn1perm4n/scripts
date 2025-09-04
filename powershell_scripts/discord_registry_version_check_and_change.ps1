# This script queries and changes the Discord DisplayVersion Registry value based on user input. Discord fails to update the Registry when it updates itself, which results in programs such as WinGet erroneously reporting Discord as being out-of-date.

# Registry path
$registryDiscordPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Discord"

# Property name
$propertyName = "DisplayVersion"

# Check if the registry path exists
if (-not (Test-Path $registryDiscordPath)) {
    Write-Host "Error: The specified Registry path does not exist."
    exit
}

# Get the current DisplayVersion value
try {
    $currentValue = (Get-ItemProperty -Path $registryDiscordPath -Name $propertyName).$propertyName
    Write-Host "Current value of '$propertyName' at '$registryDiscordPath': $currentValue"
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
    Set-ItemProperty -Path $registryDiscordPath -Name $propertyName -Value $newValue -Force
    Write-Host "Registry value '$propertyName' at '$registryDiscordPath' successfully updated to '$newValue'."
}
catch {
    Write-Host "Error: Could not update the Registry value. Ensure you have the necessary permissions."
}

Write-Host "Successfully updated Discord version number in the Registry."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.