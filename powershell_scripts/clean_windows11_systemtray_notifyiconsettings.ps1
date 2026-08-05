# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script removes duplicate/redundant keys in HKEY_CURRENT_USER\Control Panel\NotifyIconSettings (System Tray icons)

# NOTE: This script is intended for Windows 11 only — the NotifyIconSettings registry path does not exist on Windows 10

# NOTE2: If a program is no longer visible in the System Tray that you expect to be there, or vice versa, re-open the affected program and manually reconfigure its System Tray visibility via Settings -> Personalization -> Taskbar -> Other system tray icons

# Optional flags:
#     -Backup <PATH>: Back up NotifyIconSettings to a .reg file before making changes (default location: %USERPROFILE%\Desktop)
#     -DeleteAll: Delete all flagged keys without prompting
#     -List: Show all NotifyIconSettings keys without processing
#     -NoConsoleOutput: Suppress console output (requires -DeleteAll and -SaveResults)
#     -Preview: Show what would be deleted without making any changes (backup is skipped)
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[string]$Backup,
	[switch]$DeleteAll,
	[switch]$List,
	[switch]$NoConsoleOutput,
	[switch]$Preview,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup <PATH>] [-DeleteAll] [-List] [-NoConsoleOutput] [-Preview] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup <PATH>       Back up NotifyIconSettings to a .reg file before making changes" -ForegroundColor Cyan
	Write-Host "                       Default location if no path supplied: %USERPROFILE%\Desktop" -ForegroundColor Cyan
	Write-Host "  -DeleteAll           Delete all flagged keys without prompting" -ForegroundColor Cyan
	Write-Host "  -List                Show all NotifyIconSettings keys without processing" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -DeleteAll and -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Preview             Show what would be deleted without making any changes (backup is skipped)" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# Validate -SaveResults path if specified
if ($SaveResults) {
	$saveDir = Split-Path $SaveResults -Parent
	if ($saveDir -and -not (Test-Path $saveDir)) {
		Write-Host ""
		Write-Error "The directory for -SaveResults does not exist: '$saveDir'"
		exit 1
	}
}

# Validate -Backup path if specified
if ($PSBoundParameters.ContainsKey('Backup') -and $Backup -ne '' -and -not (Test-Path (Split-Path $Backup -Parent))) {
	Write-Host ""
	Write-Error "The directory for -Backup does not exist: '$(Split-Path $Backup -Parent)'"
	exit 1
}

# -NoConsoleOutput requires -DeleteAll and -SaveResults, since without -DeleteAll this script
# can still block on the delete confirmation prompt with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not $DeleteAll -or -not $SaveResults)) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -DeleteAll and -SaveResults."
	exit 1
}

$FileOutputLines = @()
$deletedCount = 0
$totalFlaggedCount = 0

$registryPath = "HKCU:\Control Panel\NotifyIconSettings"

if (-not (Test-Path $registryPath)) {
	$errorMessage = "Registry path not found: $registryPath"
	if ($NoConsoleOutput) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$errorMessage`n")
		}
		catch {
			Write-Host ""
			Write-Error $errorMessage
		}
	}
	else {
		Write-Host ""
		Write-Error $errorMessage
	}
	exit 1
}

# P/Invoke definition for RegQueryInfoKey, which is the Windows API function
# required to retrieve the last write time of a registry key
$regQueryInfoKeySource = @"
using System;
using System.Runtime.InteropServices;
public class RegHelper {
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    public static extern int RegQueryInfoKey(
        IntPtr hKey,
        IntPtr lpClass,
        IntPtr lpcchClass,
        IntPtr lpReserved,
        IntPtr lpcSubKeys,
        IntPtr lpcbMaxSubKeyLen,
        IntPtr lpcbMaxClassLen,
        IntPtr lpcValues,
        IntPtr lpcbMaxValueNameLen,
        IntPtr lpcbMaxValueLen,
        IntPtr lpcbSecurityDescriptor,
        out long lpftLastWriteTime
    );
}
"@
Add-Type -TypeDefinition $regQueryInfoKeySource

$subkeys = Get-ChildItem -Path $registryPath -ErrorAction SilentlyContinue

if (-not $subkeys) {
	$warningMessage = "$ScriptName`: No subkeys found."
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Warning $warningMessage
	}
	if ($SaveResults) {
		try {
			[System.IO.File]::WriteAllText($SaveResults, $warningMessage)
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}
	exit 0
}

$entries = @()
foreach ($key in $subkeys) {
	$exePath = $key.GetValue("ExecutablePath")
	if (-not $exePath) { continue }

	$isPromoted = $key.GetValue("IsPromoted")
	$shownInTaskbar = if ($isPromoted -eq 1) {
		"Yes"
	}
	elseif ($isPromoted -eq 0) {
		"No"
	}
	else {
		"Unknown"
	}

	# Retrieve LastWriteTime via RegQueryInfoKey Windows API
	$lastWriteTime = $null
	try {
		$regKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Control Panel\NotifyIconSettings\$($key.PSChildName)")
		if ($regKey) {
			$handle = $regKey.Handle.DangerousGetHandle()
			$lastWriteRaw = 0L
			$result = [RegHelper]::RegQueryInfoKey(
				$handle,
				[IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero,
				[IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero,
				[IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero,
				[IntPtr]::Zero,
				[ref]$lastWriteRaw
			)
			$regKey.Close()
			if ($result -eq 0) {
				$lastWriteTime = [DateTime]::FromFileTimeUtc($lastWriteRaw).ToLocalTime()
			}
		}
	} catch {
		$null = $_
	}

	# Strip versioned folder segments from path to normalize for grouping
	$segments = $exePath -split '\\'
	$filtered = $segments | Where-Object {
		$_ -notmatch '^(app|version|v|release)?[-_]?\d+\.\d+[\.\d]*$'
	}
	$normalizedPath = $filtered -join '\'

	# Extract version from path if present
	$version = $null
	if ($exePath -match '(\d+\.\d+[\.\d]*)') {
		try { $version = [version]$Matches[1] } catch { $null = $_ }
	}

	$entries += [PSCustomObject]@{
		KeyName = $key.PSChildName
		ExecutablePath = $exePath
		NormalizedPath = $normalizedPath
		Version = $version
		LastWriteTime = $lastWriteTime
		ShownInTaskbar = $shownInTaskbar
	}
}

# -List: show all keys without processing and exit
if ($List) {
	if (-not $NoConsoleOutput) { Write-Host "`nListing all keys in: $registryPath`n" -ForegroundColor Cyan }
	if ($SaveResults) { $FileOutputLines += "Listing all keys in: $registryPath" }

	foreach ($entry in $entries) {
		if (-not $NoConsoleOutput) {
			Write-Host $entry.KeyName
			Write-Host "     ExecutablePath  : $($entry.ExecutablePath)"
			Write-Host "     LastWriteTime   : $($entry.LastWriteTime)"
			Write-Host "     ShownInTaskbar  : $($entry.ShownInTaskbar)"
			Write-Host ""
		}
		if ($SaveResults) {
			$FileOutputLines += $entry.KeyName
			$FileOutputLines += "     ExecutablePath  : $($entry.ExecutablePath)"
			$FileOutputLines += "     LastWriteTime   : $($entry.LastWriteTime)"
			$FileOutputLines += "     ShownInTaskbar  : $($entry.ShownInTaskbar)"
			$FileOutputLines += ""
		}
	}

	$summaryLine = "$ScriptName`: Total keys: $($entries.Count)"
	if (-not $NoConsoleOutput) { Write-Host $summaryLine -ForegroundColor Cyan }

	if ($SaveResults) {
		$FileOutputLines += $summaryLine
		while ($FileOutputLines[-1] -eq '') {
			$FileOutputLines = $FileOutputLines[0..($FileOutputLines.Count - 2)]
		}
		try {
			$outputString = ($FileOutputLines -join "`n")
			[System.IO.File]::WriteAllText($SaveResults, $outputString)
			if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to: $SaveResults" -ForegroundColor Green }
		}
		catch {
			# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}

	exit 0
}

if (-not $NoConsoleOutput) { Write-Host "`nScanning: $registryPath`n" -ForegroundColor Cyan }

$groups = $entries | Group-Object -Property NormalizedPath
$duplicateGroups = $groups | Where-Object { $_.Count -ge 2 }

if (-not $duplicateGroups) {
	$messageLine = "$ScriptName`: No duplicate groups found."
	if (-not $NoConsoleOutput) { Write-Host $messageLine -ForegroundColor Green }
	if ($SaveResults) {
		try {
			[System.IO.File]::WriteAllText($SaveResults, $messageLine)
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}
	exit 0
}

$totalFlaggedCount = ($duplicateGroups | ForEach-Object { $_.Count - 1 } | Measure-Object -Sum).Sum

# Perform backup if -Backup is specified and -Preview is not
if ($PSBoundParameters.ContainsKey('Backup') -and -not $Preview) {
	$backupPath = if ($Backup -ne '') {
		$Backup
	}
	else {
		"$env:USERPROFILE\Desktop\NotifyIconSettings_backup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').reg"
	}
	try {
		reg export "HKCU\Control Panel\NotifyIconSettings" $backupPath /y 2>&1 | Out-Null
		if (-not $NoConsoleOutput) { Write-Host "Backup saved to: $backupPath`n" -ForegroundColor Green }
		if ($SaveResults) { $FileOutputLines += "Backup saved to: $backupPath" }
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Could not save backup: $($_.Exception.Message)"
		}
		if ($SaveResults) { $FileOutputLines += "Could not save backup: $($_.Exception.Message)" }
	}
}

foreach ($group in $duplicateGroups | Sort-Object Name) {
	$versioned = $group.Group | Where-Object { $null -ne $_.Version }

	if ($versioned) {
		$keeper = $versioned | Sort-Object Version -Descending | Select-Object -First 1
	}
	else {
		$keeper = $group.Group | Sort-Object LastWriteTime -Descending | Select-Object -First 1
	}

	if (-not $NoConsoleOutput) {
		Write-Host "----------------------------------------" -ForegroundColor DarkGray
		Write-Host "Group: $($group.Name)" -ForegroundColor Yellow
		Write-Host "  Entries: $($group.Count)"
	}
	if ($SaveResults) {
		$FileOutputLines += "----------------------------------------"
		$FileOutputLines += "Group: $($group.Name)"
		$FileOutputLines += "  Entries: $($group.Count)"
	}

	foreach ($entry in $group.Group | Sort-Object ExecutablePath) {
		$isKeeper = ($entry.KeyName -eq $keeper.KeyName)
		$tag = if ($isKeeper) {
			"[KEEP]"
		}
		else {
			"[REMOVE]"
		}
		$color = if ($isKeeper) {
			"Green"
		}
		else {
			"Red"
		}
		$ver = if ($entry.Version) {
			" (v$($entry.Version))"
		}
		else {
			""
		}

		if (-not $NoConsoleOutput) {
			Write-Host "  $tag $($entry.KeyName)$ver" -ForegroundColor $color
			Write-Host "       ExecutablePath  : $($entry.ExecutablePath)"
			Write-Host "       LastWriteTime   : $($entry.LastWriteTime)"
			Write-Host "       ShownInTaskbar  : $($entry.ShownInTaskbar)"
		}
		if ($SaveResults) {
			$FileOutputLines += "  $tag $($entry.KeyName)$ver"
			$FileOutputLines += "       ExecutablePath  : $($entry.ExecutablePath)"
			$FileOutputLines += "       LastWriteTime   : $($entry.LastWriteTime)"
			$FileOutputLines += "       ShownInTaskbar  : $($entry.ShownInTaskbar)"
		}

		if (-not $isKeeper) {
			if ($Preview) {
				if (-not $NoConsoleOutput) { Write-Host "  Would delete: $($entry.KeyName)" -ForegroundColor Yellow }
				if ($SaveResults) { $FileOutputLines += "  Would delete: $($entry.KeyName)" }
				$deletedCount++
			}
			else {
				if (-not $DeleteAll) {
					$response = Read-Host "`n  Delete '$($entry.KeyName)'? (Y/N)"
					if ($response -notmatch '^[Yy]$') {
						if (-not $NoConsoleOutput) { Write-Host "  Skipped: $($entry.KeyName)" -ForegroundColor Yellow }
						if ($SaveResults) { $FileOutputLines += "  Skipped: $($entry.KeyName)" }
						continue
					}
				}
				try {
					Remove-Item -Path "HKCU:\Control Panel\NotifyIconSettings\$($entry.KeyName)" -Recurse -Force -ErrorAction Stop
					if (-not $NoConsoleOutput) { Write-Host "  Deleted: $($entry.KeyName)" -ForegroundColor Yellow }
					if ($SaveResults) { $FileOutputLines += "  Deleted: $($entry.KeyName)" }
					$deletedCount++
				}
				catch {
					if (-not $NoConsoleOutput) {
						Write-Host ""
						Write-Warning "Could not delete $($entry.KeyName): $($_.Exception.Message)"
					}
					if ($SaveResults) { $FileOutputLines += "Could not delete $($entry.KeyName): $($_.Exception.Message)" }
				}
			}
		}
	}

	if (-not $NoConsoleOutput) { Write-Host "" }
	if ($SaveResults) { $FileOutputLines += "" }
}

if (-not $NoConsoleOutput) { Write-Host "" }
if ($Preview) {
	$summaryLine = "$ScriptName`: Preview complete. $deletedCount of $totalFlaggedCount key(s) would be deleted."
	if (-not $NoConsoleOutput) { Write-Host $summaryLine -ForegroundColor Cyan }
}
else {
	$summaryLine = "$ScriptName`: $deletedCount of $totalFlaggedCount key(s) deleted."
	if (-not $NoConsoleOutput) { Write-Host $summaryLine -ForegroundColor Green }
}

if (-not $NoConsoleOutput) {
	Write-Host @"
`nNOTE: If a program is no longer visible in the System Tray that you expect to be there, or vice versa,
re-open the affected program and manually reconfigure its System Tray visibility via
Settings -> Personalization -> Taskbar -> Other system tray icons
"@ -ForegroundColor Cyan
}

if ($SaveResults) {
	$FileOutputLines += $summaryLine
	$FileOutputLines += ""
	$FileOutputLines += "NOTE: If a program is no longer visible in the System Tray that you expect to be there, or vice versa,"
	$FileOutputLines += "re-open the affected program and manually reconfigure its System Tray visibility via"
	$FileOutputLines += "Settings -> Personalization -> Taskbar -> Other system tray icons"

	while ($FileOutputLines[-1] -eq '') {
		$FileOutputLines = $FileOutputLines[0..($FileOutputLines.Count - 2)]
	}

	try {
		$outputString = ($FileOutputLines -join "`n")
		[System.IO.File]::WriteAllText($SaveResults, $outputString)
		if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to: $SaveResults" -ForegroundColor Green }
	}
	catch {
		# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.