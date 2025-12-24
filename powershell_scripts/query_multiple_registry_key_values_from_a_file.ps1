# This script queries Registry values from file "keys.txt". Create keys.txt and include the values you'd like to query. Here's an example:
# HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowSyncProviderNotifications
# HKLM:\Software\Policies\Microsoft\Dsh\AllowWidgets
# HKCU\Software\Policies\Microsoft\Windows\Explorer\DisableSearchBoxSuggestions
# To make things simple, place the script and keys.txt in the same folder and run from there. Please also note that the lines in keys.txt can either use a colon or no colon (i.e. HKCU:\ or HKCU\).

# Ensure the script never terminates early
$ErrorActionPreference = 'Continue'

# Locate keys.txt in the same directory as the script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$registryListFile = Join-Path $scriptDir 'keys.txt'

# Verify the input file exists
if (-not (Test-Path $registryListFile)) {
	Write-Host "File not found: $registryListFile" -ForegroundColor Red
	return
}

# Process each line in the file
Get-Content -Path $registryListFile | ForEach-Object {

	# Clean up input
	$rawPath = $_.Trim()
	if (-not $rawPath) { return }

	Write-Host "--- Reading Path: $rawPath ---" -ForegroundColor Cyan

	# Normalize FULL hive names
	$path = $rawPath
	$path = $path -replace '^HKEY_LOCAL_MACHINE\\','HKLM:\'
	$path = $path -replace '^HKEY_CURRENT_USER\\','HKCU:\'
	$path = $path -replace '^HKEY_CLASSES_ROOT\\','HKCR:\'
	$path = $path -replace '^HKEY_USERS\\','HKU:\'
	$path = $path -replace '^HKEY_CURRENT_CONFIG\\','HKCC:\'

	# Normalize shorthand hive names
	$path = $path -replace '^HKLM\\','HKLM:\'
	$path = $path -replace '^HKCU\\','HKCU:\'
	$path = $path -replace '^HKCR\\','HKCR:\'
	$path = $path -replace '^HKU\\','HKU:\'
	$path = $path -replace '^HKCC\\','HKCC:\'

	# Split into parent key and leaf
	$parentKey = Split-Path $path -Parent
	$leafName  = Split-Path $path -Leaf

	try {
		# Case 1: Full path is a registry KEY
		if (Test-Path $path) {
			$properties = Get-ItemProperty -Path $path -ErrorAction Stop
			$values = $properties | Select-Object * -ExcludeProperty `
				PSPath, PSParentPath, PSChildName, PSDrive, PSProvider

			if ($values.PSObject.Properties.Count -eq 0) {
				Write-Host "(Key has no values)" -ForegroundColor DarkGray
			}
			else {
				$values | Format-List
			}
		}
		# Case 2: Parent exists → treat leaf as VALUE
		elseif (Test-Path $parentKey) {
			try {
				$value = Get-ItemPropertyValue -Path $parentKey -Name $leafName -ErrorAction Stop
				Write-Host "$leafName : $value"
			}
			catch {
				Write-Host "Value does not exist in key." -ForegroundColor Yellow
			}
		}
		# Case 3: Neither exists
		else {
			Write-Host "Registry key does not exist." -ForegroundColor Yellow
		}
	}
	catch {
		Write-Host "Unable to read registry path." -ForegroundColor Red
	}

	Write-Host ""
}

# End.