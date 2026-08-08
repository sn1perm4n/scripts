# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script searches files or directories for a user-defined string and replaces it with a user-defined replacement string

# Optional flags:
#     -Backup: Automatically create backups before modifying files (skips interactive prompt)
#     -CaseSensitive: Perform a case-sensitive search (default is case-insensitive)
#     -NoConsoleOutput: Suppress console output (requires -Path, -SearchString, -ReplaceString, -Backup, and -SaveResults)
#     -Path <PATH>: Path to a file or a folder (prompts if not specified)
#     -Recurse: Include files in subdirectories
#     -ReplaceString <TEXT>: The replacement text (prompts if not specified)
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -SearchString <TEXT>: The text to search for (prompts if not specified)
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Backup,
	[switch]$CaseSensitive,
	[switch]$NoConsoleOutput,
	[string]$Path,
	[switch]$Recurse,
	[string]$ReplaceString,
	[string]$SaveResults,
	[string]$SearchString,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup] [-CaseSensitive] [-NoConsoleOutput] [-Path <PATH>] [-Recurse] [-ReplaceString <TEXT>] [-SaveResults <PATH>] [-SearchString <TEXT>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup                Automatically create backups before modifying files (skips interactive prompt)" -ForegroundColor Cyan
	Write-Host "  -CaseSensitive         Perform a case-sensitive search (default is case-insensitive)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput       Suppress console output (requires -Path, -SearchString, -ReplaceString, -Backup, and -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>           Path to a file or a folder (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Recurse               Include files in subdirectories" -ForegroundColor Cyan
	Write-Host "  -ReplaceString <TEXT>  The replacement text (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>    Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
	Write-Host "  -SearchString <TEXT>   The text to search for (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Help                  Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
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

# -NoConsoleOutput requires -Path, -SearchString, -ReplaceString, -Backup, and -SaveResults, since without
# all of these this script can still block on interactive prompts with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not $Path -or -not $SearchString -or -not $ReplaceString -or -not $Backup -or -not $SaveResults)) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -Path, -SearchString, -ReplaceString, -Backup, and -SaveResults."
	exit 1
}

# Prompt user for file or folder path, search string, and replacement string if not specified
if (-not $Path) {
	$Path = Read-Host "`nEnter the full path to a file or a folder"
}

if (-not (Test-Path $Path)) {
	$errorMessage = "Path not found: $Path"
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

if (-not $SearchString) {
	$SearchString = Read-Host "`nEnter the text to search for"
}

if (-not $ReplaceString) {
	$ReplaceString = Read-Host "`nEnter the replacement text"
}

$item = Get-Item $Path

# Collect files
$files = if ($item.PSIsContainer) {
	Get-ChildItem -Path $Path -File -Recurse:$Recurse
}
else {
	@($item)
}

if (-not $files -or $files.Count -eq 0) {
	$warningMessage = "$ScriptName`: No files found."
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

# Initialize counters and output lines
$matchedCount = 0
$replacedCount = 0
$FileOutputLines = @()

if (-not $NoConsoleOutput) { Write-Host "`nScanning for '$searchString'...`n" -ForegroundColor Cyan }

# First pass: scan all files and collect matches
$fileMatchMap = @{}

foreach ($file in $files) {
	try {
		$content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Could not read $($file.Name): $($_.Exception.Message)"
		}
		if ($SaveResults) { $FileOutputLines += "Could not read $($file.Name): $($_.Exception.Message)" }
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
		if (-not $NoConsoleOutput) { Write-Host $line -ForegroundColor Yellow }
		if ($SaveResults) { $FileOutputLines += $line }
	}
}

if ($matchedCount -eq 0) {
	$summaryLine = "$ScriptName`: Scan complete. No matches found for '$searchString'."
	if (-not $NoConsoleOutput) { Write-Host $summaryLine -ForegroundColor Green }

	if ($SaveResults) {
		$FileOutputLines += $summaryLine

		try {
			$outputString = ($FileOutputLines -join "`n")
			[System.IO.File]::WriteAllText($SaveResults, $outputString)
			if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green }
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
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
if (-not $NoConsoleOutput) { Write-Host "" }
foreach ($file in $files) {
	if (-not $fileMatchMap.ContainsKey($file.FullName)) {
		continue
	}

	try {
		$content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop

		if ($doBackup) {
			$backupPath = $file.FullName + ".bak"
			Copy-Item -Path $file.FullName -Destination $backupPath -Force -ErrorAction Stop
			if (-not $NoConsoleOutput) { Write-Host "Backup created: $backupPath" -ForegroundColor Cyan }
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
		if (-not $NoConsoleOutput) { Write-Host "Replaced in: $($file.Name)" -ForegroundColor Green }
		if ($SaveResults) { $FileOutputLines += "Replaced in: $($file.Name)" }
		$replacedCount++
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Could not process $($file.Name): $($_.Exception.Message)"
		}
		if ($SaveResults) { $FileOutputLines += "Could not process $($file.Name): $($_.Exception.Message)" }
	}
}

# Summary
$summaryLine = "$ScriptName`: Complete. $matchedCount file(s) contained matches, $replacedCount file(s) updated."
if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }

# Save results to text file if requested
if ($SaveResults) {
	$FileOutputLines += ""
	$FileOutputLines += $summaryLine

	while ($FileOutputLines[-1] -eq '') {
		$FileOutputLines = $FileOutputLines[0..($FileOutputLines.Count - 2)]
	}

	try {
		$outputString = ($FileOutputLines -join "`n")
		[System.IO.File]::WriteAllText($SaveResults, $outputString)
		if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green }
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