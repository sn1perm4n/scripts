# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script prompts the user to enter a full registry path that includes both the registry key and the value name. Both common input formats are handled, i.e.:
# HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProductName
# HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProductName

# NOTE: Must be run as Administrator if querying protected registry locations

# Prompt user for registry path
$registryPath = Read-Host "`nEnter full registry path (including value name)"

# Normalize common hive shortcuts
$registryPath = $registryPath -replace '^HKLM\\', 'HKLM:\'
$registryPath = $registryPath -replace '^HKCU\\', 'HKCU:\'
$registryPath = $registryPath -replace '^HKCR\\', 'HKCR:\'
$registryPath = $registryPath -replace '^HKU\\', 'HKU:\'
$registryPath = $registryPath -replace '^HKCC\\', 'HKCC:\'

# Split registry path into key and value
try {
	$registryKey = Split-Path $registryPath -Parent
	$valueName = Split-Path $registryPath -Leaf

	if (-not $registryKey -or -not $valueName) {
		throw "Invalid registry path format."
	}
}
catch {
	Write-Host ""
	Write-Warning "Invalid registry path format. Please provide a full registry path including a value name."
	Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit 1
}

try {
	# Attempt to get all properties of the registry key
	$item = Get-ItemProperty -Path $registryKey -ErrorAction Stop

	# Exact match for the registry value
	$property = $item.PSObject.Properties | Where-Object { $_.Name -eq $valueName }

	if ($property) {
		$value = $item.$valueName
		Write-Host "`nRegistry Value Found:" -ForegroundColor Green
		Write-Host "$valueName = $value" -ForegroundColor Green
	}
	else {
		Write-Host ""
		Write-Warning "Registry value '$valueName' does not exist."
	}
}
catch [System.Management.Automation.ProviderNotFoundException] {
	Write-Host ""
	Write-Warning "Registry key '$registryKey' does not exist."
}
catch [System.UnauthorizedAccessException] {
	Write-Host ""
	Write-Warning "Access denied. Run PowerShell as Administrator."
}
catch [System.Security.SecurityException] {
	Write-Host ""
	Write-Warning "Access denied. Run PowerShell as Administrator."
}
catch {
	Write-Host ""
	Write-Warning "Unable to read registry key '$registryKey'."
}

# Pause for any key press before exiting
Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.