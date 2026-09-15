# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script adds a user-supplied line of text as a comment to the top of various script files

# NOTE: .reg files must keep "Windows Registry Editor Version 5.00" as the first line, so the comment targets the second line instead. The same second-line targeting applies to .sh files that begin with a shebang (i.e. #!/bin/bash) and to .ahk files (which always begin with #Requires).

# NOTE2: To support additional file types or comment formats, add an entry to the alphabetized $commentMap below. If a new file type also needs second-line targeting, add its extension to the check further down in the script.

# NOTE3: Each file's target line is checked directly (not "anywhere in the file"). An exact match is skipped. A line that starts with that file type's comment character but doesn't match is flagged for review and left alone unless -Force is specified, in which case it is overwritten. A target line that isn't already a comment is never overwritten regardless of -Force; a new line is inserted instead.

# Optional flags:
#     -Backup:             Automatically create backups before modifying files (skips interactive prompt)
#     -Force:              Overwrite an existing mismatched header line (never overwrites a line that is not already a comment)
#     -NoConsoleOutput:    Suppress console output (requires -Path, -Text, -SaveResults, and one of -Backup/-Preview)
#     -Path <PATH>:        Path to the folder to process (prompts if not specified)
#     -Preview:            Show which files would be modified, overwritten, or flagged without changing anything
#     -Recurse:            Include files in subdirectories
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Text <TEXT>:        The text to add as a header comment (prompts if not specified)
#     -Help / -?:          Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Backup,
	[switch]$Force,
	[switch]$NoConsoleOutput,
	[string]$Path,
	[switch]$Preview,
	[switch]$Recurse,
	[string]$SaveResults,
	[string]$Text,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup] [-Force] [-NoConsoleOutput] [-Path <PATH>] [-Preview] [-Recurse] [-SaveResults <PATH>] [-Text <TEXT>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup              Automatically create backups before modifying files (skips interactive prompt)" -ForegroundColor Cyan
	Write-Host "  -Force               Overwrite an existing mismatched header line (never overwrites a line that is not already a comment)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -Path, -Text, -SaveResults, and one of -Backup/-Preview)" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>         Path to the folder to process (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Preview             Show which files would be modified, overwritten, or flagged without changing anything" -ForegroundColor Cyan
	Write-Host "  -Recurse             Include files in subdirectories" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
	Write-Host "  -Text <TEXT>         The text to add as a header comment (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# -NoConsoleOutput requires -Path, -Text, -SaveResults, and one of -Backup or -Preview, since without
# all of these this script can still block on an interactive prompt with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not $Path -or -not $Text -or -not $SaveResults -or -not ($Backup -or $Preview))) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -Path, -Text, -SaveResults, and one of -Backup or -Preview."
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
}

# Prompt for the text to add if not specified via -Text
if (-not $Text) {
	$Text = Read-Host "`nEnter the text to add to the first line of each script (second line for .reg/.sh/.ahk files)"
}

# Prompt for the folder to process if not specified via -Path
if (-not $Path) {
	$Path = Read-Host "`nEnter the full path to the folder to process"
}

if (-not (Test-Path $Path)) {
	Write-Host ""
	Write-Error "Path not found: $Path"
	exit 1
}

# Determine whether to create backups
$doBackup = $false
if ($Backup) {
	$doBackup = $true
}
elseif (-not $Preview) {
	Write-Host ""
	$backupResponse = Read-Host "Would you like to create a backup of all of the files before modifying them? (Y/N)"
	if ($backupResponse -match '^[Yy]$') {
		$doBackup = $true
	}
}

# Define file types and their comment characters (additional file types/comment formats can be added here)
$commentMap = @{
	'.ahk' = ';'
	'.bat' = 'REM'
	'.ps1' = '#'
	'.reg' = ';'
	'.sh'  = '#'
}

$files = Get-ChildItem -Path $Path -File -Recurse:$Recurse | Where-Object { $commentMap.ContainsKey($_.Extension) }

if (-not $files) {
	$warningMessage = "$ScriptName`: No matching files found."
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

$FileOutputLines = @()
$processedCount = 0
$alreadyCorrectCount = 0
$mismatchCount = 0

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

	$commentChar = $commentMap[$file.Extension]
	$lineToAdd = "$commentChar $Text"
	$lines = @($content -split "`r?`n")

	# Determine the target line index (0-based) for this file type
	if ($file.Extension -eq '.sh') {
		$firstLine = if ($lines.Count -gt 0) { $lines[0] } else { '' }
		$targetLineIndex = if ($firstLine -like '#!*') { 1 } else { 0 }
	}
	elseif ($file.Extension -in '.ahk', '.reg') {
		$targetLineIndex = 1
	}
	else {
		$targetLineIndex = 0
	}

	$existingLine = if ($lines.Count -gt $targetLineIndex) { $lines[$targetLineIndex] } else { $null }

	# Already correct: skip
	if ($existingLine -eq $lineToAdd) {
		$line = "Already correct: $($file.Name)"
		if (-not $NoConsoleOutput) { Write-Host $line -ForegroundColor Yellow }
		if ($SaveResults) { $FileOutputLines += $line }
		$alreadyCorrectCount++
		continue
	}

	# A target line that already looks like a comment (right or wrong) is only overwritten with -Force;
	# a target line that doesn't look like a comment is never overwritten, regardless of -Force
	$looksLikeExistingHeader = $existingLine -and $existingLine.TrimStart().StartsWith($commentChar)

	if ($looksLikeExistingHeader -and -not $Force) {
		$line = "Mismatch on line $($targetLineIndex + 1) of $($file.Name): '$existingLine' (use -Force to overwrite)"
		if (-not $NoConsoleOutput) { Write-Host $line -ForegroundColor Yellow }
		if ($SaveResults) { $FileOutputLines += $line }
		$mismatchCount++
		continue
	}

	$action = if ($looksLikeExistingHeader -and $Force) { 'overwrite' } else { 'insert' }

	$before = if ($targetLineIndex -gt 0) { @($lines | Select-Object -First $targetLineIndex) } else { @() }
	$after = if ($action -eq 'overwrite') { @($lines | Select-Object -Skip ($targetLineIndex + 1)) } else { @($lines | Select-Object -Skip $targetLineIndex) }
	$newLines = @($before) + @($lineToAdd) + @($after)
	$newContent = $newLines -join [Environment]::NewLine

	if ($Preview) {
		$verb = if ($action -eq 'overwrite') { "Would overwrite line $($targetLineIndex + 1) of" } else { "Would add line to" }
		$line = "$verb $($file.Name)"
		if (-not $NoConsoleOutput) { Write-Host $line -ForegroundColor Yellow }
		if ($SaveResults) { $FileOutputLines += $line }
		$processedCount++
		continue
	}

	try {
		if ($doBackup) {
			$backupPath = $file.FullName + ".bak"
			Copy-Item -Path $file.FullName -Destination $backupPath -Force -ErrorAction Stop
			if (-not $NoConsoleOutput) { Write-Host "Backup created for $($file.Name) at $backupPath" -ForegroundColor Cyan }
			if ($SaveResults) { $FileOutputLines += "Backup created for $($file.Name) at $backupPath" }
		}

		[System.IO.File]::WriteAllText($file.FullName, $newContent, $fileEncoding)
		$verb = if ($action -eq 'overwrite') { "Overwrote line $($targetLineIndex + 1) of" } else { "Added line to" }
		$line = "$verb $($file.Name)"
		if (-not $NoConsoleOutput) { Write-Host $line -ForegroundColor Green }
		if ($SaveResults) { $FileOutputLines += $line }
		$processedCount++
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Could not write to $($file.Name): $($_.Exception.Message)"
		}
		if ($SaveResults) { $FileOutputLines += "Could not write to $($file.Name): $($_.Exception.Message)" }
	}
}

# Summary
if ($Preview) {
	$summaryLine = "$ScriptName`: Preview complete. $processedCount file(s) would be modified, $alreadyCorrectCount already correct, $mismatchCount flagged for review (use -Force to overwrite). No files were modified."
}
else {
	$summaryLine = "$ScriptName`: Complete. $processedCount file(s) modified, $alreadyCorrectCount already correct, $mismatchCount flagged for review (use -Force to overwrite)."
}
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