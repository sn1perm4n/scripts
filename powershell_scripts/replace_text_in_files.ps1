# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script searches files or directories for a user-defined string and replaces it with a user-defined replacement string.

# Optional flags:
#     -Backup: Automatically create backups before modifying files (skips interactive prompt)
#     -CaseSensitive: Perform a case-sensitive search (default is case-insensitive)
#     -Recurse: Include files in subdirectories
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Backup,
	[switch]$CaseSensitive,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup] [-CaseSensitive] [-Recurse] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup              Automatically create backups before modifying files (skips interactive prompt)" -ForegroundColor Cyan
	Write-Host "  -CaseSensitive       Perform a case-sensitive search (default is case-insensitive)" -ForegroundColor Cyan
	Write-Host "  -Recurse             Include files in subdirectories" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# Validate -SaveResults path if specified
if ($SaveResults) {
	$saveDir = Split-Path $SaveResults -Parent
	if ($saveDir -and -not (Test-Path $saveDir)) {
		Write-Error "The directory for -SaveResults does not exist: '$saveDir'"
		exit 1
	}
}

# Prompt user for path, search string, and replacement string
$Path = Read-Host "`nEnter the full path to a file or directory"

if (-not (Test-Path $Path)) {
	Write-Error "Path not found: $Path"
	exit 1
}

$searchString  = Read-Host "`nEnter the text to search for"
$replaceString = Read-Host "`nEnter the replacement text"

$item = Get-Item $Path

# Collect files
$files = if ($item.PSIsContainer) {
	Get-ChildItem -Path $Path -File -Recurse:$Recurse
}
else {
	@($item)
}

if (-not $files -or $files.Count -eq 0) {
	Write-Host "`nNo files found." -ForegroundColor Yellow
	exit 0
}

# Initialize counters and output lines
$matchedCount    = 0
$replacedCount   = 0
$FileOutputLines = @()

Write-Host "`nScanning for '$searchString'...`n" -ForegroundColor Cyan

# First pass: scan all files and collect matches
$fileMatchMap = @{}

foreach ($file in $files) {
	try {
		$content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
	}
	catch {
		Write-Warning "Could not read $($file.Name): $($_.Exception.Message)"
		continue
	}

	$hasMatch = if ($CaseSensitive) {
		$content -cmatch [regex]::Escape($searchString)
	}
	else {
		$content -imatch [regex]::Escape($searchString)
	}

	if ($hasMatch) {
		$fileMatchMap[$file.FullName] = $true
		$matchedCount++
		$line = "Found in: $($file.FullName)"
		Write-Host $line -ForegroundColor Yellow
		if ($SaveResults) { $FileOutputLines += $line }
	}
}

if ($matchedCount -eq 0) {
	$summaryLine = "Scan complete. No matches found for '$searchString'."
	Write-Host $summaryLine -ForegroundColor Green

	if ($SaveResults) {
		$FileOutputLines += $summaryLine
		$outputString = ($FileOutputLines -join "`n")
		[System.IO.File]::WriteAllText($SaveResults, $outputString)
		Write-Host "`nResults saved to text file: $SaveResults" -ForegroundColor Green
	}

	exit 0
}

# Determine whether to create backups
$doBackup = $false
if ($Backup) {
	$doBackup = $true
}
else {
	Write-Host ""
	$backupResponse = Read-Host "Would you like to create backups before replacing? (Y/N)"
	if ($backupResponse -match '^[Yy]$') {
		$doBackup = $true
	}
}

# Second pass: replace in matched files
Write-Host ""
foreach ($file in $files) {
	if (-not $fileMatchMap.ContainsKey($file.FullName)) {
		continue
	}

	try {
		$content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop

		if ($doBackup) {
			$backupPath = $file.FullName + ".bak"
			Copy-Item -Path $file.FullName -Destination $backupPath -Force -ErrorAction Stop
			Write-Host "Backup created: $backupPath" -ForegroundColor Cyan
			if ($SaveResults) { $FileOutputLines += "Backup created: $backupPath" }
		}

		$newContent = if ($CaseSensitive) {
			$content -creplace [regex]::Escape($searchString), $replaceString
		}
		else {
			$content -ireplace [regex]::Escape($searchString), $replaceString
		}

		$utf8Bom = New-Object System.Text.UTF8Encoding $true
		[System.IO.File]::WriteAllText($file.FullName, $newContent, $utf8Bom)
		Write-Host "Replaced in: $($file.Name)" -ForegroundColor Green
		if ($SaveResults) { $FileOutputLines += "Replaced in: $($file.Name)" }
		$replacedCount++
	}
	catch {
		Write-Warning "Could not process $($file.Name): $($_.Exception.Message)"
	}
}

# Summary
$summaryLine = "Complete. $matchedCount file(s) contained matches, $replacedCount file(s) updated."
Write-Host "`n$summaryLine" -ForegroundColor Green

# Save results to text file if requested
if ($SaveResults) {
	$FileOutputLines += ""
	$FileOutputLines += $summaryLine

	while ($FileOutputLines[-1] -eq '') {
		$FileOutputLines = $FileOutputLines[0..($FileOutputLines.Count - 2)]
	}

	$outputString = ($FileOutputLines -join "`n")
	[System.IO.File]::WriteAllText($SaveResults, $outputString)

	Write-Host "`nResults saved to text file: $SaveResults" -ForegroundColor Green
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.