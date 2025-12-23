# This script prompts the user to enter a full registry path that includes both the registry key and the value name. Both common input formats are handled, i.e.:
# HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProductName
# HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProductName
# Must be run as Administrator if querying protected registry locations
#Requires -RunAsAdministrator

# Ensure script runs as Administrator
$principal = New-Object Security.Principal.WindowsPrincipal `
	([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $principal.IsInRole(
	[Security.Principal.WindowsBuiltInRole]::Administrator
)) {
	Write-Host "Please run this script as Administrator. Press any key to exit..." -ForegroundColor Red
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit 1
}

# Ensure the script never terminates early
$ErrorActionPreference = 'Continue'

# Prompt user for registry path
$registryPath = Read-Host "Enter full registry path (including value name)"

# Normalize common hive shortcuts
$registryPath = $registryPath -replace '^HKLM\\', 'HKLM:\'
$registryPath = $registryPath -replace '^HKCU\\', 'HKCU:\'
$registryPath = $registryPath -replace '^HKCR\\', 'HKCR:\'
$registryPath = $registryPath -replace '^HKU\\',  'HKU:\'
$registryPath = $registryPath -replace '^HKCC\\', 'HKCC:\'

# Split registry path into key and value
try {
	$registryKey = Split-Path $registryPath -Parent
	$valueName   = Split-Path $registryPath -Leaf

	if (-not $registryKey -or -not $valueName) {
		throw "Invalid registry path format."
	}
}
catch {
	Write-Host "Invalid registry path format. Please provide a full registry path including a value name." -ForegroundColor Red
	$registryKey = $null
	$valueName = $null
}

if ($registryKey -and $valueName) {
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
			Write-Host "Registry value '$valueName' does not exist." -ForegroundColor Red
		}
	}
	catch [System.Management.Automation.ProviderNotFoundException] {
		Write-Host "Registry key '$registryKey' does not exist." -ForegroundColor Red
	}
	catch [System.UnauthorizedAccessException] {
		Write-Host "Access denied. Run PowerShell as Administrator." -ForegroundColor Red
	}
	catch [System.Security.SecurityException] {
		Write-Host "Access denied. Run PowerShell as Administrator." -ForegroundColor Red
	}
	catch {
		Write-Host "Unable to read registry key '$registryKey'." -ForegroundColor Red
	}
}

# Pause for any key press before exiting
Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# End.