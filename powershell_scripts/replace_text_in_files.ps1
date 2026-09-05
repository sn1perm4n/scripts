# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script searches files or directories for a user-defined string and replaces it with a user-defined replacement string

# NOTE: The replacement text is inserted literally via a MatchEvaluator, so characters with special meaning in .NET regex replacement syntax (i.e. $1, $&) in -ReplaceString are treated as plain text, not substitution sequences

# NOTE2: Each file's original encoding (UTF-8 BOM, UTF-8 no BOM, UTF-16 LE, UTF-16 BE) is detected and preserved on write, rather than forcing UTF-8 BOM on every file

# Optional flags:
#     -Backup:               Automatically create backups before modifying files (skips interactive prompt)
#     -CaseSensitive:        Perform a case-sensitive search (default is case-insensitive)
#     -NoConsoleOutput:      Suppress console output (requires -Path, -SearchString, -ReplaceString, -SaveResults, and one of -Backup/-Preview)
#     -Path <PATH>:          Path to a file or a folder (prompts if not specified)
#     -Preview:              Show matched files and occurrence counts without modifying anything
#     -Recurse:              Include files in subdirectories
#     -ReplaceString <TEXT>: The replacement text (prompts if not specified)
#     -SaveResults <PATH>:   Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -SearchString <TEXT>:  The text to search for (prompts if not specified)
#     -Help / -?:            Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Backup,
	[switch]$CaseSensitive,
	[switch]$NoConsoleOutput,
	[string]$Path,
	[switch]$Preview,
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
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup] [-CaseSensitive] [-NoConsoleOutput] [-Path <PATH>] [-Preview] [-Recurse] [-ReplaceString <TEXT>] [-SaveResults <PATH>] [-SearchString <TEXT>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup                Automatically create backups before modifying files (skips interactive prompt)" -ForegroundColor Cyan
	Write-Host "  -CaseSensitive         Perform a case-sensitive search (default is case-insensitive)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput       Suppress console output (requires -Path, -SearchString, -ReplaceString, -SaveResults, and one of -Backup/-Preview)" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>           Path to a file or a folder (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Preview               Show matched files and occurrence counts without modifying anything" -ForegroundColor Cyan
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

# Write the hostname as a header line the first time this file is created, so a fleet of per-machine files can be identified at a glance
if ($SaveResults -and -not (Test-Path $SaveResults)) {
	try {
		[System.IO.File]::AppendAllText($SaveResults, "$env:COMPUTERNAME`:`n")
	}
	catch {
		Write-Host ""
		Write-Warning "Could not write hostname header to '$SaveResults': $($_.Exception.Message)"
	}
}

# -NoConsoleOutput requires -Path, -SearchString, -ReplaceString, -SaveResults, and one of -Backup or -Preview, since without
# all of these this script can still block on interactive prompts with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not $Path -or -not $SearchString -or -not $ReplaceString -or -not $SaveResults -or -not ($Backup -or $Preview))) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -Path, -SearchString, -ReplaceString, -SaveResults, and one of -Backup or -Preview."
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

# Build the search regex once, reused for both counting and (via MatchEvaluator) literal replacement
$regexOptions = if ($CaseSensitive) { [System.Text.RegularExpressions.RegexOptions]::None } else { [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
$searchRegex = New-Object System.Text.RegularExpressions.Regex([regex]::Escape($SearchString), $regexOptions)
$replacementEvaluator = [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $ReplaceString }

# Initialize counters and output lines
$matchedFileCount = 0
$totalOccurrences = 0
$FileOutputLines = @()

if (-not $NoConsoleOutput) { Write-Host "`nScanning for '$SearchString'...`n" -ForegroundColor Cyan }

# First pass: scan all files, detect each file's encoding, and count occurrences
$fileMatchMap = @{}
$fileEncodingMap = @{}
$fileBomLengthMap = @{}

foreach ($file in $files) {
	try {
		$bytes = [System.IO.File]::ReadAllBytes($file.FullName)

		$bomLength = 0
		if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
			$fileEncoding = New-Object System.Text.UTF8Encoding $true
			$bomLength = 3
		}
		elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
			$fileEncoding = [System.Text.Encoding]::Unicode
			$bomLength = 2
		}
		elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
			$fileEncoding = [System.Text.Encoding]::BigEndianUnicode
			$bomLength = 2
		}
		else {
			$fileEncoding = New-Object System.Text.UTF8Encoding $false
			$bomLength = 0
		}

		$content = $fileEncoding.GetString($bytes, $bomLength, $bytes.Length - $bomLength)
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Could not read $($file.Name): $($_.Exception.Message)"
		}
		if ($SaveResults) { $FileOutputLines += "Could not read $($file.Name): $($_.Exception.Message)" }
		continue
	}

	$occurrenceCount = $searchRegex.Matches($content).Count

	if ($occurrenceCount -gt 0) {
		$fileMatchMap[$file.FullName] = $occurrenceCount
		$fileEncodingMap[$file.FullName] = $fileEncoding
		$fileBomLengthMap[$file.FullName] = $bomLength
		$matchedFileCount++
		$totalOccurrences += $occurrenceCount
		$line = "Found $occurrenceCount occurrence(s) in: $($file.FullName)"
		if (-not $NoConsoleOutput) { Write-Host $line -ForegroundColor Yellow }
		if ($SaveResults) { $FileOutputLines += $line }
	}
}

if ($matchedFileCount -eq 0) {
	$summaryLine = "$ScriptName`: Scan complete. No matches found for '$SearchString'."
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

# Preview mode: report matches without modifying anything
if ($Preview) {
	$summaryLine = "$ScriptName`: Preview complete. $matchedFileCount file(s) contain $totalOccurrences total occurrence(s) of '$SearchString'. Would replace with: '$ReplaceString'. No files were modified."
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Yellow }

	if ($SaveResults) {
		$FileOutputLines += ""
		$FileOutputLines += $summaryLine

		while ($FileOutputLines.Count -gt 0 -and $FileOutputLines[-1] -eq '') {
			$FileOutputLines = @($FileOutputLines | Select-Object -First ($FileOutputLines.Count - 1))
		}

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

# Second pass: replace in matched files, preserving each file's original encoding
if (-not $NoConsoleOutput) { Write-Host "" }
$replacedCount = 0
foreach ($file in $files) {
	if (-not $fileMatchMap.ContainsKey($file.FullName)) {
		continue
	}

	try {
		$fileEncoding = $fileEncodingMap[$file.FullName]
		$bomLength = $fileBomLengthMap[$file.FullName]
		$bytes = [System.IO.File]::ReadAllBytes($file.FullName)
		$content = $fileEncoding.GetString($bytes, $bomLength, $bytes.Length - $bomLength)

		if ($doBackup) {
			$backupPath = $file.FullName + ".bak"
			Copy-Item -Path $file.FullName -Destination $backupPath -Force -ErrorAction Stop
			if (-not $NoConsoleOutput) { Write-Host "Backup created: $backupPath" -ForegroundColor Cyan }
			if ($SaveResults) { $FileOutputLines += "Backup created: $backupPath" }
		}

		$newContent = $searchRegex.Replace($content, $replacementEvaluator)

		[System.IO.File]::WriteAllText($file.FullName, $newContent, $fileEncoding)
		if (-not $NoConsoleOutput) { Write-Host "Replaced $($fileMatchMap[$file.FullName]) occurrence(s) in: $($file.Name)" -ForegroundColor Green }
		if ($SaveResults) { $FileOutputLines += "Replaced $($fileMatchMap[$file.FullName]) occurrence(s) in: $($file.Name)" }
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
$summaryLine = "$ScriptName`: Complete. $matchedFileCount file(s) contained matches, $replacedCount file(s) updated."
if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }

# Save results to text file if requested
if ($SaveResults) {
	$FileOutputLines += ""
	$FileOutputLines += $summaryLine

	while ($FileOutputLines.Count -gt 0 -and $FileOutputLines[-1] -eq '') {
		$FileOutputLines = @($FileOutputLines | Select-Object -First ($FileOutputLines.Count - 1))
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