# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script checks a folder of PowerShell scripts or an individual PowerShell script for space indentation and replaces it with tab indentation

# Optional flags:
#     -Backup:             Automatically create backups before modifying files (skips interactive prompt)
#     -ConvertAll:         Automatically process all files without prompting
#     -NoConsoleOutput:    Suppress console output (requires -SaveResults, and one of -ConvertAll/-Preview)
#     -Path <PATH>:        Path to a .ps1 file or a folder (prompts if not specified)
#     -Preview:            Show which files/lines would be re-indented without modifying anything
#     -Recurse:            Include files in subdirectories
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Help / -?:          Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Backup,
	[switch]$ConvertAll,
	[switch]$NoConsoleOutput,
	[string]$Path,
	[switch]$Preview,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup] [-ConvertAll] [-NoConsoleOutput] [-Path <PATH>] [-Preview] [-Recurse] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup              Automatically create backups before modifying files (skips interactive prompt)" -ForegroundColor Cyan
	Write-Host "  -ConvertAll          Automatically process all files without prompting" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -SaveResults, and one of -ConvertAll/-Preview)" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>         Path to a .ps1 file or a folder (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Preview             Show which files/lines would be re-indented without modifying anything" -ForegroundColor Cyan
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
		Write-Host ""
		Write-Error "The directory for -SaveResults does not exist: '$saveDir'"
		exit 1
	}
}

# -NoConsoleOutput requires -SaveResults, and one of -ConvertAll or -Preview, since without one of
# those this script can still block on an interactive prompt with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not ($ConvertAll -or $Preview) -or -not $SaveResults)) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults, and one of -ConvertAll or -Preview."
	exit 1
}

# Number of spaces per tab
$spacesPerTab = 4

# Prompt user for file or folder path if not specified
if (-not $Path) {
	$Path = Read-Host "`nEnter the full path to a .ps1 file or a folder containing scripts"
}
$scriptFileOrDirectory = $Path

# Validate the path
if (-not (Test-Path $scriptFileOrDirectory)) {
	$errorMessage = "The path '$scriptFileOrDirectory' does not exist."
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

# Determine if path is a directory or a single file
if ((Get-Item $scriptFileOrDirectory).PSIsContainer) {
	$files = Get-ChildItem -Path $scriptFileOrDirectory -Filter *.ps1 -Recurse:$Recurse
	if ($files.Count -eq 0) {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "$ScriptName`: No .ps1 files found in the directory."
		}
		if ($SaveResults) {
			try {
				[System.IO.File]::WriteAllText($SaveResults, "$ScriptName`: No .ps1 files found in the directory.")
			}
			catch {
				Write-Host ""
				Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
			}
		}
		exit 0
	}
}
else {
	if ($scriptFileOrDirectory -notlike "*.ps1") {
		$errorMessage = "The file '$scriptFileOrDirectory' is not a .ps1 script."
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
	$files = @(Get-Item $scriptFileOrDirectory)
}

# Initialize counters and output lines
$modifiedCount = 0
$FileOutputLines = @()

# Determine whether to create backups
$doBackup = $false
if ($Backup) {
	$doBackup = $true
}
else {
	if (-not $ConvertAll -and -not $Preview) {
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
	if (-not $NoConsoleOutput) { Write-Host "`nProcessing: $file" -ForegroundColor Cyan }

	$changed = $false
	$newContent = @()
	$lineNumber = 0

	try {
		$originalLines = Get-Content $file -ErrorAction Stop
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Could not read $($fileObj.Name): $($_.Exception.Message)"
		}
		if ($SaveResults) {
			$FileOutputLines += "Could not read $($fileObj.Name): $($_.Exception.Message)"
		}
		continue
	}

	foreach ($line in $originalLines) {
		$lineNumber++

		# Match any leading whitespace (spaces or tabs)
		if ($line -match '^([ \t]+)') {
			$leading = $matches[1]

			# Count total spaces: treat tabs as $spacesPerTab spaces
			$spaceCount = ($leading -replace "`t", (" " * $spacesPerTab)).Length
			$tabCount = [math]::Floor($spaceCount / $spacesPerTab)
			$remainingSpaces = $spaceCount % $spacesPerTab

			# Build new leading whitespace (tabs + leftover spaces)
			$newIndent = ("`t" * $tabCount) + (" " * $remainingSpaces)
			$newLine = $newIndent + $line.Substring($leading.Length)

			# Only mark as changed if the line actually differs
			if ($newLine -ne $line) {
				$line = $newLine
				$changed = $true
				if (-not $NoConsoleOutput) {
					$verb = if ($Preview) { "would replace" } else { "replaced" }
					Write-Host "  Line $lineNumber`: $verb leading spaces with $tabCount tab(s) + $remainingSpaces space(s)" -ForegroundColor Yellow
				}
			}
		}
		$newContent += $line
	}

	if ($changed) {
		if ($Preview) {
			if (-not $NoConsoleOutput) { Write-Host "  Would update: $file" -ForegroundColor Yellow }
			if ($SaveResults) {
				$FileOutputLines += "Would update: $file"
			}
			$modifiedCount++
		}
		else {
			try {
				if ($doBackup) {
					$backupPath = "$file.bak"
					Copy-Item $file $backupPath -Force -ErrorAction Stop
					if (-not $NoConsoleOutput) { Write-Host "  Backup created: $backupPath" -ForegroundColor Cyan }
					if ($SaveResults) {
						$FileOutputLines += "Backup created: $backupPath"
					}
				}

				$utf8Bom = New-Object System.Text.UTF8Encoding $true
				[System.IO.File]::WriteAllLines($file, $newContent, $utf8Bom)
				if (-not $NoConsoleOutput) { Write-Host "  Updated: $file" -ForegroundColor Green }
				if ($SaveResults) {
					$FileOutputLines += "Updated: $file"
				}
				$modifiedCount++
			}
			catch {
				if (-not $NoConsoleOutput) {
					Write-Host ""
					Write-Warning "Could not write to $($fileObj.Name): $($_.Exception.Message)"
				}
				if ($SaveResults) {
					$FileOutputLines += "Could not write to $($fileObj.Name): $($_.Exception.Message)"
				}
			}
		}
	}
	else {
		if (-not $NoConsoleOutput) { Write-Host "  No changes needed." -ForegroundColor Yellow }
		if ($SaveResults) {
			$FileOutputLines += "No changes needed: $file"
		}
	}
}

# Summary
$verb = if ($Preview) { "would be" } else { "were" }
$summaryLine = "$ScriptName`: Complete. $modifiedCount file(s) $verb modified."
if (-not $NoConsoleOutput) {
	if ($modifiedCount -gt 0) {
		Write-Host "`n$summaryLine" -ForegroundColor Green
	}
	else {
		Write-Host ""
		Write-Warning $summaryLine
	}
}

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

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.