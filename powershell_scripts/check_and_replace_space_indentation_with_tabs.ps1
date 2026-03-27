# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script checks a folder of PowerShell scripts or an individual PowerShell script for space indentation and replaces it with tab indentation

# Optional flags:
#     -Backup: Automatically create backups before modifying files (skips interactive prompt)
#     -ConvertAll: Automatically process all files without prompting
#     -Recurse: Include files in subdirectories
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Backup,
	[switch]$ConvertAll,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup] [-ConvertAll] [-Recurse] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup              Automatically create backups before modifying files (skips interactive prompt)" -ForegroundColor Cyan
	Write-Host "  -ConvertAll          Automatically process all files without prompting" -ForegroundColor Cyan
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

# Number of spaces per tab
$spacesPerTab = 4

# Prompt the user for a directory or individual script file
$scriptFileOrDirectory = Read-Host "`nEnter the path to a PowerShell script directory or a single .ps1 file"

# Validate the path
if (-not (Test-Path $scriptFileOrDirectory)) {
	Write-Error "The path '$scriptFileOrDirectory' does not exist."
	exit 1
}

# Determine if path is a directory or a single file
if ((Get-Item $scriptFileOrDirectory).PSIsContainer) {
	$files = Get-ChildItem -Path $scriptFileOrDirectory -Filter *.ps1 -Recurse:$Recurse
	if ($files.Count -eq 0) {
		Write-Host "`nNo .ps1 files found in the directory." -ForegroundColor Yellow
		exit 0
	}
}
else {
	if ($scriptFileOrDirectory -notlike "*.ps1") {
		Write-Error "The file '$scriptFileOrDirectory' is not a .ps1 script."
		exit 1
	}
	$files = @(Get-Item $scriptFileOrDirectory)
}

# Initialize counters and output lines
$modifiedCount   = 0
$FileOutputLines = @()

# Determine whether to create backups
$doBackup = $false
if ($Backup) {
	$doBackup = $true
}
else {
	if (-not $ConvertAll) {
		Write-Host ""
		$backupResponse = Read-Host "Would you like to create backups before modifying? (Y/N)"
		if ($backupResponse -match '^[Yy]$') {
			$doBackup = $true
		}
	}
}

# Process each file
foreach ($fileObj in $files) {
	$file = $fileObj.FullName
	Write-Host "`nProcessing: $file" -ForegroundColor Cyan

	$changed    = $false
	$newContent = @()
	$lineNumber = 0

	foreach ($line in Get-Content $file) {
		$lineNumber++

		# Match any leading whitespace (spaces or tabs)
		if ($line -match '^([ \t]+)') {
			$leading = $matches[1]

			# Count total spaces: treat tabs as $spacesPerTab spaces
			$spaceCount      = ($leading -replace "`t", (" " * $spacesPerTab)).Length
			$tabCount        = [math]::Floor($spaceCount / $spacesPerTab)
			$remainingSpaces = $spaceCount % $spacesPerTab

			# Build new leading whitespace (tabs + leftover spaces)
			$newIndent = ("`t" * $tabCount) + (" " * $remainingSpaces)
			$newLine   = $newIndent + $line.Substring($leading.Length)

			# Only mark as changed if the line actually differs
			if ($newLine -ne $line) {
				$line    = $newLine
				$changed = $true
				Write-Host "  Line $lineNumber`: replaced leading spaces with $tabCount tab(s) + $remainingSpaces space(s)" -ForegroundColor Yellow
			}
		}
		$newContent += $line
	}

	if ($changed) {
		try {
			if ($doBackup) {
				$backupPath = "$file.bak"
				Copy-Item $file $backupPath -Force -ErrorAction Stop
				Write-Host "  Backup created: $backupPath" -ForegroundColor Cyan
				if ($SaveResults) {
					$FileOutputLines += "Backup created: $backupPath"
				}
			}

			$utf8Bom = New-Object System.Text.UTF8Encoding $true
			[System.IO.File]::WriteAllLines($file, $newContent, $utf8Bom)
			Write-Host "  Updated: $file" -ForegroundColor Green
			if ($SaveResults) {
				$FileOutputLines += "Updated: $file"
			}
			$modifiedCount++
		}
		catch {
			Write-Warning "Could not write to $($fileObj.Name): $($_.Exception.Message)"
		}
	}
	else {
		Write-Host "  No changes needed." -ForegroundColor Green
		if ($SaveResults) {
			$FileOutputLines += "No changes needed: $file"
		}
	}
}

# Summary
$summaryLine = "Complete. $modifiedCount file(s) modified."
if ($modifiedCount -gt 0) {
	Write-Host "`n$summaryLine" -ForegroundColor Green
}
else {
	Write-Host "`n$summaryLine" -ForegroundColor Yellow
}

# Save results if requested
if ($SaveResults) {
	$FileOutputLines += ""
	$FileOutputLines += $summaryLine

	while ($FileOutputLines[-1] -eq '') {
		$FileOutputLines = $FileOutputLines[0..($FileOutputLines.Count - 2)]
	}

	try {
		$outputString = ($FileOutputLines -join "`n")
		[System.IO.File]::WriteAllText($SaveResults, $outputString)
		Write-Host "`nResults saved to text file: $SaveResults" -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.