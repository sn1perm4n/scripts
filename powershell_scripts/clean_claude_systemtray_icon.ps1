# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script removes stale Claude system tray icon entries from HKCU\Control Panel\NotifyIconSettings and enables the remaining entry so Claude appears in the system tray without manual configuration

# NOTE: This script is intended for Windows 11 only — the NotifyIconSettings registry path does not exist on Windows 10

# NOTE2: Claude updates frequently and each update registers a new system tray icon entry. This script identifies the newest version by extracting the version number from either the classic Electron/Squirrel installer path (an app-x.x.x folder) or the newer MSIX-packaged path (WindowsApps\Claude_x.x.x.x_platform__hash\app\claude.exe), deletes all older entries, and promotes the active entry.

# NOTE3: MSIX-packaged ExecutablePath values may reference a KNOWNFOLDERID GUID instead of a literal drive path (i.e. {6D809377-6AF0-444B-8957-A3773F02200E} for Program Files). This script resolves the GUIDs it recognizes; unrecognized ones are reported as "Unknown" for ExistsOnDisk rather than incorrectly reported as missing.

# NOTE4: The WindowsApps folder has restrictive permissions by default, even for administrators, so ExistsOnDisk may be inaccurate for MSIX entries even when Claude is properly installed. This field is diagnostic only and does not affect the stale-cleanup/promotion logic, which relies on version comparison.

# NOTE5: If Claude is not visible in the System Tray after running this script, re-open Claude and manually configure its System Tray visibility via Settings -> Personalization -> Taskbar -> Other system tray icons

# Optional flags:
#     -Preview: Show what would be changed without making any changes
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Preview,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Preview] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Preview  Show what would be changed without making any changes" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

$registryPath = "HKCU:\Control Panel\NotifyIconSettings"

if (-not (Test-Path $registryPath)) {
	Write-Host ""
	Write-Error "Registry path not found: $registryPath"
	exit 1
}

$subkeys = Get-ChildItem -Path $registryPath -ErrorAction SilentlyContinue

if (-not $subkeys) {
	Write-Host "`nNo subkeys found in NotifyIconSettings." -ForegroundColor Yellow
	exit 0
}

# Known KNOWNFOLDERID GUIDs that may appear in place of a literal path in MSIX-packaged ExecutablePath values
$knownFolderMap = @{
	'{6D809377-6AF0-444B-8957-A3773F02200E}' = $env:ProgramFiles
	'{7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E}' = ${env:ProgramFiles(x86)}
}

# Collect all Claude entries
$claudeEntries = @()
foreach ($key in $subkeys) {
	$exePath = $key.GetValue("ExecutablePath")
	if (-not $exePath) { continue }
	if ($exePath -notmatch '(?i)claude') { continue }

	$isPromoted = $key.GetValue("IsPromoted")

	# Extract version from either the classic Electron/Squirrel app-x.x.x folder or the newer MSIX Claude_x.x.x.x_platform__hash folder
	$version = $null
	if ($exePath -match '(?i)app-(\d+\.\d+[\.\d]*)') {
		try { $version = [version]$Matches[1] } catch { $null = $_ }
	}
	elseif ($exePath -match '(?i)Claude_(\d+(?:\.\d+)+)_') {
		try { $version = [version]$Matches[1] } catch { $null = $_ }
	}

	# Resolve a leading KNOWNFOLDERID GUID to a literal path if recognized, so ExistsOnDisk can be checked accurately
	$resolvedExePath = $exePath
	$unresolvedKnownFolder = $false
	if ($exePath -match '^(\{[0-9A-Fa-f-]{36}\})(\\.*)$') {
		$folderGuid = $Matches[1]
		$remainder = $Matches[2]
		if ($knownFolderMap.ContainsKey($folderGuid)) {
			$resolvedExePath = "$($knownFolderMap[$folderGuid])$remainder"
		}
		else {
			$unresolvedKnownFolder = $true
		}
	}

	$existsOnDisk = if ($unresolvedKnownFolder) { $null } else { Test-Path $resolvedExePath -ErrorAction SilentlyContinue }

	$claudeEntries += [PSCustomObject]@{
		KeyName = $key.PSChildName
		ExecutablePath = $exePath
		IsPromoted = $isPromoted
		Version = $version
		ExistsOnDisk = $existsOnDisk
	}
}

if ($claudeEntries.Count -eq 0) {
	Write-Host "`nNo Claude entries found in NotifyIconSettings." -ForegroundColor Yellow
	exit 0
}

Write-Host "`nFound $($claudeEntries.Count) Claude entry/entries in NotifyIconSettings:" -ForegroundColor Cyan
foreach ($entry in $claudeEntries) {
	$diskStatus = if ($null -eq $entry.ExistsOnDisk) { "Unknown (unrecognized known-folder reference)" } elseif ($entry.ExistsOnDisk) { "exists on disk" } else { "NOT found on disk" }
	$promotedStatus = if ($entry.IsPromoted -eq 1) { "Yes" } elseif ($entry.IsPromoted -eq 0) { "No" } else { "Unknown" }
	$versionDisplay = if ($entry.Version) { $entry.Version.ToString() } else { "unknown" }
	Write-Host "  $($entry.KeyName)" -ForegroundColor Cyan
	Write-Host "       ExecutablePath  : $($entry.ExecutablePath)"
	Write-Host "       Version         : $versionDisplay"
	Write-Host "       ExistsOnDisk    : $diskStatus"
	Write-Host "       IsPromoted      : $promotedStatus"
}

# Determine keeper — highest versioned entry; fall back to disk existence if no versions found
$versionedEntries = $claudeEntries | Where-Object { $null -ne $_.Version }

$activeEntry = if ($versionedEntries) {
	$versionedEntries | Sort-Object Version -Descending | Select-Object -First 1
}
else {
	$claudeEntries | Where-Object { $_.ExistsOnDisk } | Select-Object -First 1
}

if (-not $activeEntry) {
	Write-Host ""
	Write-Warning "Could not determine which Claude entry to keep. No changes made."
	exit 1
}

$staleEntries = $claudeEntries | Where-Object { $_.KeyName -ne $activeEntry.KeyName }

if ($staleEntries.Count -eq 0 -and $activeEntry.IsPromoted -eq 1) {
	Write-Host "`n$ScriptName`: Claude system tray entry is already clean and promoted. No changes needed." -ForegroundColor Green
	exit 0
}

Write-Host ""

# Delete stale entries
$deletedCount = 0
foreach ($entry in $staleEntries) {
	if ($Preview) {
		Write-Host "Would delete stale entry: $($entry.KeyName)" -ForegroundColor Yellow
		Write-Host "       ExecutablePath  : $($entry.ExecutablePath)"
		$deletedCount++
	}
	else {
		try {
			Remove-Item -Path "$registryPath\$($entry.KeyName)" -Recurse -Force -ErrorAction Stop
			Write-Host "Deleted stale entry: $($entry.KeyName)" -ForegroundColor Yellow
			Write-Host "       ExecutablePath  : $($entry.ExecutablePath)"
			$deletedCount++
		}
		catch {
			Write-Host ""
			Write-Warning "Could not delete $($entry.KeyName): $($_.Exception.Message)"
		}
	}
}

# Enable IsPromoted on the active entry
if ($activeEntry.IsPromoted -ne 1) {
	if ($Preview) {
		Write-Host "`nWould enable IsPromoted for: $($activeEntry.KeyName)" -ForegroundColor Cyan
		Write-Host "       ExecutablePath  : $($activeEntry.ExecutablePath)"
	}
	else {
		try {
			Set-ItemProperty -Path "$registryPath\$($activeEntry.KeyName)" -Name "IsPromoted" -Value 1 -Type DWord -Force -ErrorAction Stop
			Write-Host "`nEnabled IsPromoted for: $($activeEntry.KeyName)" -ForegroundColor Green
			Write-Host "       ExecutablePath  : $($activeEntry.ExecutablePath)"
		}
		catch {
			Write-Host ""
			Write-Warning "Could not set IsPromoted for $($activeEntry.KeyName): $($_.Exception.Message)"
		}
	}
}
else {
	if ($Preview) {
		Write-Host "`nIsPromoted already enabled for active entry: $($activeEntry.KeyName)" -ForegroundColor Cyan
	}
	else {
		Write-Host "`nIsPromoted already enabled for active entry: $($activeEntry.KeyName)" -ForegroundColor Green
	}
}

# Restart File Explorer to apply changes
if (-not $Preview) {
	Write-Host "`nRestarting File Explorer to apply changes..." -ForegroundColor Cyan
	try {
		Stop-Process -Name explorer -Force -ErrorAction Stop
		Start-Sleep -Milliseconds 500
		Start-Process explorer
		Write-Host "File Explorer restarted successfully." -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Warning "Could not restart File Explorer: $($_.Exception.Message)"
	}
}

Write-Host ""
if ($Preview) {
	$summaryLine = "$ScriptName`: Preview complete. $deletedCount stale entry/entries would be deleted."
	Write-Host $summaryLine -ForegroundColor Cyan
}
else {
	$summaryLine = "$ScriptName`: $deletedCount stale entry/entries deleted. Claude system tray icon cleaned and promoted successfully."
	Write-Host $summaryLine -ForegroundColor Green
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.