# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script previews duplicate/redundant keys in HKEY_CURRENT_USER\Control Panel\NotifyIconSettings

# NOTE: This is a preview-only script — it makes no changes to the registry
# NOTE: This script is intended for Windows 11 only — the NotifyIconSettings registry path does not exist on Windows 10

# Optional flags:
#     -Help / -?: Display this help message

[CmdletBinding()]
param (
	[switch]$Help
)

$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Help    Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
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

function Get-Version {
	param ([string]$Path)
	if ($Path -match '(\d+\.\d+[\.\d]*)') {
		try { return [version]$Matches[1] } catch {}
	}
	return $null
}

function Get-NormalizedPath {
	param ([string]$ExePath)
	$segments = $ExePath -split '\\'
	$filtered = $segments | Where-Object {
		$_ -notmatch '^(app|version|v|release)?[-_]?\d+\.\d+[\.\d]*$'
	}
	return ($filtered -join '\')
}

function Get-RegistryKeyLastWriteTime {
	param ([string]$SubKeyName)
	try {
		$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Control Panel\NotifyIconSettings\$SubKeyName")
		if ($key) {
			$handle = $key.Handle.DangerousGetHandle()
			$lastWriteTime = 0L
			$result = [RegHelper]::RegQueryInfoKey(
				$handle,
				[IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero,
				[IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero,
				[IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero,
				[IntPtr]::Zero,
				[ref]$lastWriteTime
			)
			$key.Close()
			if ($result -eq 0) {
				return [DateTime]::FromFileTimeUtc($lastWriteTime).ToLocalTime()
			}
		}
	} catch {}
	return $null
}

$registryPath = "HKCU:\Control Panel\NotifyIconSettings"

if (-not (Test-Path $registryPath)) {
	Write-Host ""
	Write-Error "Registry path not found: $registryPath"
	exit 1
}

Write-Host "`nScanning: $registryPath`n" -ForegroundColor Cyan

$subkeys = Get-ChildItem -Path $registryPath -ErrorAction SilentlyContinue

if (-not $subkeys) {
	Write-Host "No subkeys found." -ForegroundColor Yellow
	exit 0
}

$entries = @()
foreach ($key in $subkeys) {
	$exePath = $key.GetValue("ExecutablePath")
	if (-not $exePath) { continue }

	$isPromoted = $key.GetValue("IsPromoted")
	$shownInTaskbar = if ($isPromoted -eq 1) { "Yes" } elseif ($isPromoted -eq 0) { "No" } else { "Unknown" }

	$entries += [PSCustomObject]@{
		KeyName = $key.PSChildName
		ExecutablePath = $exePath
		NormalizedPath = Get-NormalizedPath -ExePath $exePath
		Version = Get-Version -Path $exePath
		LastWriteTime = Get-RegistryKeyLastWriteTime -SubKeyName $key.PSChildName
		ShownInTaskbar = $shownInTaskbar
	}
}

$groups = $entries | Group-Object -Property NormalizedPath

$duplicateGroupCount = 0
$totalFlaggedCount = 0

foreach ($group in $groups | Sort-Object Name) {
	if ($group.Count -lt 2) { continue }

	$duplicateGroupCount++
	Write-Host "----------------------------------------" -ForegroundColor DarkGray
	Write-Host "Group: $($group.Name)" -ForegroundColor Yellow
	Write-Host "  Entries: $($group.Count)"

	$versioned = $group.Group | Where-Object { $null -ne $_.Version }

	if ($versioned) {
		$keeper = $versioned | Sort-Object Version -Descending | Select-Object -First 1
	} else {
		$keeper = $group.Group | Sort-Object LastWriteTime -Descending | Select-Object -First 1
	}

	foreach ($entry in $group.Group | Sort-Object ExecutablePath) {
		$isKeeper = ($entry.KeyName -eq $keeper.KeyName)
		$tag = if ($isKeeper) { "[KEEP]" } else { "[REMOVE]" }
		$color = if ($isKeeper) { "Green" } else { "Red" }
		$ver = if ($entry.Version) { " (v$($entry.Version))" } else { "" }

		Write-Host "  $tag $($entry.KeyName)$ver" -ForegroundColor $color
		Write-Host "       ExecutablePath  : $($entry.ExecutablePath)"
		Write-Host "       LastWriteTime   : $($entry.LastWriteTime)"
		Write-Host "       ShownInTaskbar  : $($entry.ShownInTaskbar)"

		if (-not $isKeeper) { $totalFlaggedCount++ }
	}

	Write-Host ""
}

Write-Host "========================================"
if ($duplicateGroupCount -eq 0) {
	Write-Host "No duplicate groups found." -ForegroundColor Green
} else {
	Write-Host "Duplicate groups found: $duplicateGroupCount" -ForegroundColor Yellow
	Write-Host "Keys flagged for removal: $totalFlaggedCount" -ForegroundColor Red
	Write-Host ""
	Write-Host "NOTE: No changes have been made to the registry." -ForegroundColor Cyan
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.