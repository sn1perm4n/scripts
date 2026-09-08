# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes the Bing shortcut that periodically reappears in the Favorites folder

# NOTE: Matches any file containing "Bing" in its name regardless of extension (i.e. Internet Shortcut .url files, not just .lnk shortcuts), since Explorer's "hide extensions" setting only affects display, not the real on-disk filename, and the recreation mechanism may not stay consistent over time

# Optional flags:
#     -NoConsoleOutput:    Suppress console output (requires -SaveResults)
#     -Preview:            Show which Bing shortcut(s) would be deleted without deleting anything
#     -SaveResults <PATH>: Save results to a text file (appends if file exists)
#     -Help / -?:          Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$NoConsoleOutput,
	[switch]$Preview,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Path to the current user's Favorites folder
$favoritesPath = Join-Path $env:USERPROFILE "Favorites"

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-NoConsoleOutput] [-Preview] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Preview             Show which Bing shortcut(s) would be deleted without deleting anything" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (appends if file exists)" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# -NoConsoleOutput requires -SaveResults, since without it there's nowhere to record results
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults."
	exit 1
}

# Validate -SaveResults path if specified
if ($SaveResults) {
	$saveDir = Split-Path $SaveResults -Parent
	if ($saveDir -and -not (Test-Path $saveDir)) {
		Write-Host ""
		Write-Error "The directory for -SaveResults does not exist: '$saveDir'"
		exit 1
	}

	# Write the hostname as a header line the first time this file is created, so a fleet of per-machine files can be identified at a glance
	if (-not (Test-Path $SaveResults)) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$env:COMPUTERNAME`:`n")
		}
		catch {
			Write-Host ""
			Write-Warning "Could not write hostname header to '$SaveResults': $($_.Exception.Message)"
		}
	}
}

if (-not (Test-Path $favoritesPath)) {
	$errorMessage = "$ScriptName`: [$env:COMPUTERNAME] Favorites folder not found: $favoritesPath"
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Error $errorMessage
	}
	if ($SaveResults) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$errorMessage`n")
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}
	exit 1
}

if (-not $NoConsoleOutput) { Write-Host "`nChecking for Bing shortcut(s) in $favoritesPath..." -ForegroundColor Cyan }

$bingShortcuts = Get-ChildItem -Path $favoritesPath -Filter "*Bing*" -File -ErrorAction SilentlyContinue

if (-not $bingShortcuts) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] No Bing shortcut(s) found."
	if (-not $NoConsoleOutput) { Write-Host $summaryLine -ForegroundColor Green }
	if ($SaveResults) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$summaryLine`n")
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

foreach ($shortcut in $bingShortcuts) {
	if ($Preview) {
		$line = "Would delete: $($shortcut.FullName)"
		if (-not $NoConsoleOutput) { Write-Host $line -ForegroundColor Yellow }
		$resultLines += $line
	}
	else {
		try {
			Remove-Item -Path $shortcut.FullName -Force -ErrorAction Stop
			$line = "Deleted: $($shortcut.FullName)"
			if (-not $NoConsoleOutput) { Write-Host $line -ForegroundColor Green }
			$resultLines += $line
			$deletedCount++
		}
		catch {
			if (-not $NoConsoleOutput) {
				Write-Host ""
				Write-Warning "Could not delete $($shortcut.FullName): $($_.Exception.Message)"
			}
			$resultLines += "Could not delete $($shortcut.FullName): $($_.Exception.Message)"
		}
	}
}

if ($Preview) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Preview complete. $($bingShortcuts.Count) Bing shortcut(s) found. No files were deleted."
}
else {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] $deletedCount of $($bingShortcuts.Count) Bing shortcut(s) deleted."
}
if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }
$resultLines += $summaryLine

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