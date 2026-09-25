# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes leftover versioned v2.X.Y folders left behind by AutoHotkey self-updates

# NOTE: This script requires elevation via #Requires -RunAsAdministrator, since Program Files folders require admin rights to modify

# NOTE2: Both the 64-bit (C:\Program Files\AutoHotkey) and 32-bit (C:\Program Files (x86)\AutoHotkey) install locations are checked, 64-bit first since it's the more common install, since a GitHub user may have either

# NOTE3: Only folders matching the pattern v2.X.Y (i.e. v2.0.26, v2.0.27) are removed; the "v2" and "UX" folders, and all files (license.txt, WindowSpy.ahk), are left untouched

# NOTE4: These leftover version folders are created each time AutoHotkey self-updates and serve no purpose once the "v2" folder itself reflects the current version

# Optional flags:
#     -DeleteAll:            Automatically delete all leftover v2.X.Y folders without prompting
#     -NoConsoleOutput:      Suppress console output (requires -DeleteAll and -SaveResults)
#     -Preview:              Show what would be deleted without making any changes
#     -SaveResults <PATH>:   Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)
#     -Help / -?:            Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$DeleteAll,
	[switch]$NoConsoleOutput,
	[switch]$Preview,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-DeleteAll] [-NoConsoleOutput] [-Preview] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -DeleteAll            Automatically delete all leftover v2.X.Y folders without prompting" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput      Suppress console output (requires -DeleteAll and -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Preview              Show what would be deleted without making any changes" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>   Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)" -ForegroundColor Cyan
	Write-Host "  -Help                 Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# -NoConsoleOutput requires -DeleteAll and -SaveResults, since without -DeleteAll this script
# can still block on an interactive prompt with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not $DeleteAll -or -not $SaveResults)) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -DeleteAll and -SaveResults."
	exit 1
}

# Validate the save path if specified
if ($SaveResults) {
	$saveDir = Split-Path $SaveResults -Parent
	if ($saveDir -and -not (Test-Path $saveDir)) {
		Write-Host ""
		Write-Error "The directory for -SaveResults does not exist: '$saveDir'"
		exit 1
	}
}

# Write the hostname as a header line the first time -SaveResults is created, so a fleet of per-machine files can be identified at a glance
if ($SaveResults -and -not (Test-Path $SaveResults)) {
	try {
		[System.IO.File]::AppendAllText($SaveResults, "$env:COMPUTERNAME`:`n")
	}
	catch {
		Write-Host ""
		Write-Warning "Could not write hostname header to '$SaveResults': $($_.Exception.Message)"
	}
}

# Check the 64-bit location first since it's the more common install, then the 32-bit location
$candidatePaths = @('C:\Program Files\AutoHotkey', 'C:\Program Files (x86)\AutoHotkey')
$installPaths = @($candidatePaths | Where-Object { Test-Path $_ })

if ($installPaths.Count -eq 0) {
	$notFoundLine = "$ScriptName`: [$env:COMPUTERNAME] AutoHotkey installation not found in either Program Files location."
	if (-not $NoConsoleOutput) { Write-Host "`n$notFoundLine" -ForegroundColor Green }
	if ($SaveResults) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$notFoundLine`n")
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}
	exit 0
}

$resultLines = @()
$deletedCount = 0
$totalBytesFreed = 0

foreach ($installPath in $installPaths) {
	# Only folders like v2.0.26 or v2.0.27 match; the "v2" and "UX" folders are excluded by requiring at least one dot after "v2"
	$oldVersionFolders = @(Get-ChildItem -Path $installPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^v2\.\d+(\.\d+)*$' })

	if (-not $NoConsoleOutput) { Write-Host "`n$installPath" -ForegroundColor Cyan }
	$resultLines += $installPath

	if ($oldVersionFolders.Count -eq 0) {
		if (-not $NoConsoleOutput) { Write-Host "  No leftover version folders found." -ForegroundColor Green }
		$resultLines += "  No leftover version folders found."
		continue
	}

	foreach ($folder in $oldVersionFolders) {
		$folderSize = (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
		if (-not $folderSize) { $folderSize = 0 }
		$folderSizeMB = [math]::Round($folderSize / 1MB, 2)

		if ($Preview) {
			if (-not $NoConsoleOutput) { Write-Host "  Would delete: $($folder.Name) ($folderSizeMB MB)" -ForegroundColor Yellow }
			$resultLines += "  Would delete: $($folder.Name) ($folderSizeMB MB)"
			$totalBytesFreed += $folderSize
			$deletedCount++
			continue
		}

		# Prompt unless -DeleteAll is specified
		if (-not $DeleteAll) {
			$response = Read-Host "`n  Delete '$($folder.Name)'? (Y/N)"
			if ($response -notmatch '^[Yy]$') {
				if (-not $NoConsoleOutput) { Write-Host "  Skipped: $($folder.Name)" -ForegroundColor Yellow }
				$resultLines += "  Skipped: $($folder.Name)"
				continue
			}
		}

		try {
			Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Stop
			$totalBytesFreed += $folderSize
			if (-not $NoConsoleOutput) { Write-Host "  Deleted: $($folder.Name) ($folderSizeMB MB)" -ForegroundColor Yellow }
			$resultLines += "  Deleted: $($folder.Name) ($folderSizeMB MB)"
			$deletedCount++
		}
		catch {
			Write-Host ""
			Write-Warning "Could not delete $($folder.FullName): $($_.Exception.Message)"
			$resultLines += "  Could not delete $($folder.FullName): $($_.Exception.Message)"
		}
	}
}

# Format total bytes freed
$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" }
else { "$totalFreedMB MB" }

# Summary
if ($Preview) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Preview complete. $deletedCount folder(s) would be deleted, freeing approximately $freedDisplay."
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Cyan }
}
else {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] $deletedCount folder(s) deleted, $freedDisplay freed."
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }
}
$resultLines += $summaryLine

# Save results
if ($SaveResults) {
	try {
		$content = ($resultLines -join "`n") + "`n"
		[System.IO.File]::AppendAllText($SaveResults, $content)
		if (-not $NoConsoleOutput) { Write-Host "`nResults saved to: $SaveResults" -ForegroundColor Green }
	}
	catch {
		# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.