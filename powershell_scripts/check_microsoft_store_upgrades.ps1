# This script checks the Microsoft Store for apps that have upgrades available, with the intention being to upgrade. Unfortunately, Microsoft Store app upgrades can't be installed in this manner because none of them appear in winget upgrade. I'm releasing this script purely for informational purposes. Please note this script also must be run as Administrator, which requires the following:
# 1. Create a shortcut to the .ps1 file, set the "Target" field to C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& C:\Users\reedwaller\Scripts\remove_game_assist.ps1"
# 2. Enable "Run as administrator" in the Shortcut tab -> Advanced)
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

# Ensure winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
	Write-Error "winget is not installed. Please install the Windows Package Manager from the Microsoft Store."
	exit 1
}

# Update winget sources to ensure latest packages
try {
	Write-Host "Updating winget sources..." -ForegroundColor Cyan
	winget source update
	Write-Host "Winget sources updated successfully." -ForegroundColor Green
}
catch {
	Write-Warning "Failed to update winget sources: $($_.Exception.Message)"
}

# Get list of installed Microsoft Store apps (PackageFamilyName)
$installedApps = Get-AppxPackage | Select-Object -ExpandProperty PackageFamilyName

# Try to get winget upgrades in JSON
try {
	$wingetOutput = winget upgrade --source msstore --accept-source-agreements --output json 2>$null
	$availableUpgrades = $wingetOutput | ConvertFrom-Json
	$usingJson = $true
}
catch {
	Write-Warning "winget JSON output failed. Falling back to parsing table output."
	$wingetOutput = winget upgrade --source msstore --accept-source-agreements 2>$null
	$usingJson = $false
}

$relevantUpgrades = @()
$upgradeIds = @()

if ($usingJson) {
	# Filter by installed apps using JSON Id
	$relevantUpgrades = $availableUpgrades | Where-Object { $installedApps -contains $_.Id }
	$upgradeIds = $availableUpgrades | Select-Object -ExpandProperty Id
}
else {
	# Parse table output and skip header line(s)
	$lines = $wingetOutput | Where-Object { $_ -and ($_ -notmatch '^Name\s+Id\s+Version\s+Available\s+Source') -and ($_ -notmatch '^-+') }
	foreach ($line in $lines) {
		# Split line by whitespace (first few columns)
		$parts = $line -split '\s{2,}' # two or more spaces
		if ($parts.Count -ge 2) {
			$name = $parts[0].Trim()
			$id   = $parts[1].Trim()
			$upgradeIds += $id
			if ($installedApps -contains $id) {
				$relevantUpgrades += [PSCustomObject]@{
					Name = $name
					Id = $id
					AvailableVersion = if ($parts.Count -ge 4) { $parts[3] } else { "Unknown" }
				}
			}
		}
	}
}

# Track skipped apps
$skippedApps = $installedApps | Where-Object { $upgradeIds -notcontains $_ }

# Display results
if ($relevantUpgrades.Count -eq 0) {
	Write-Host "No installed Microsoft Store apps have available updates." -ForegroundColor Green
}
else {
	Write-Host "Found updates for installed Microsoft Store apps:" -ForegroundColor Green
	foreach ($app in $relevantUpgrades) {
		Write-Host "  $($app.Name) ($($app.Id)) -> $($app.AvailableVersion)"
	}

	try {
		winget upgrade --source msstore --all --accept-package-agreements --accept-source-agreements
		Write-Host "Microsoft Store apps updated successfully." -ForegroundColor Green
	}
	catch {
		Write-Error "An error occurred while updating Microsoft Store apps: $($_.Exception.Message)."
	}
}

# Report skipped apps
if ($skippedApps.Count -gt 0) {
	Write-Host "`nThe following installed Microsoft Store apps do not appear in winget upgrade:" -ForegroundColor Yellow
	foreach ($app in $skippedApps) {
		Write-Host "  $app"
	}
}

# Prompt for user input to close
Write-Host "`nPress any key to exit..." -ForegroundColor Red
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
exit 1

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.