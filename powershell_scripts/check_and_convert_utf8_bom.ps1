# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script checks files for UTF-8 BOM formatting and optionally converts them to UTF-8 BOM

# Optional flags:
#     -Backup: Automatically create backups before converting files (skips interactive prompt)
#     -ConvertAll: Automatically convert all files without prompting
#     -Failures: Only show files skipped or not converted
#     -NoConsoleOutput: Suppress console output (requires -ConvertAll and -SaveResults)
#     -Path <PATH>: Path to a .ps1 or .reg file or a folder (prompts if not specified)
#     -Recurse: Include all .ps1 and .reg files in subfolders of the specified path
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Successes: Only show successfully converted filenames
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Backup,
	[switch]$ConvertAll,
	[switch]$Failures,
	[switch]$NoConsoleOutput,
	[string]$Path,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Successes,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup] [-ConvertAll] [-Failures] [-NoConsoleOutput] [-Path <PATH>] [-Recurse] [-Successes] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup              Automatically create backups before converting files (skips interactive prompt)" -ForegroundColor Cyan
	Write-Host "  -ConvertAll          Automatically convert all files without prompting" -ForegroundColor Cyan
	Write-Host "  -Failures            Only show files skipped or not converted" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -ConvertAll and -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>         Path to a .ps1 or .reg file or a folder (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Recurse             Include all .ps1 and .reg files in subfolders of the specified path" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
	Write-Host "  -Successes           Only show successfully converted filenames" -ForegroundColor Cyan
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

# -NoConsoleOutput requires -ConvertAll and -SaveResults, since without -ConvertAll this script
# can still block on interactive per-file prompts with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not $ConvertAll -or -not $SaveResults)) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -ConvertAll and -SaveResults."
	exit 1
}

# Prompt user for file or folder path if not specified
if (-not $Path) {
	$Path = Read-Host "`nEnter the full path to a .ps1 or .reg file, or a folder"
}

# Validate path exists
if (-not (Test-Path $Path)) {
	Write-Host ""
	Write-Error "Path not found: $Path"
	exit 1
}

$items = Get-Item $Path

# Include only .ps1 and .reg files
$files = if ($items.PSIsContainer) {
	Get-ChildItem -Path $Path -File -Recurse:$Recurse | Where-Object { $_.Extension -in '.ps1', '.reg' }
}
else {
	if ($items.Extension -in '.ps1', '.reg') {
		@($items)
	}
	else {
		@()
	}
}

# Quick check for no .ps1 or .reg files
if (-not $files -or $files.Count -eq 0) {
	Write-Host ""
	Write-Warning "No PowerShell (.ps1) or Registry (.reg) files found in '$Path'."
	exit 0
}

# Counters for statistics
$TotalFiles = 0
$MissingBOM = 0
$Converted = 0

# Arrays to separate successes and failures for clean output
$SuccessFiles = @()
$FailureFiles = @()

# File output lines
$FileOutputLines = @()

foreach ($file in $files) {
	$TotalFiles++

	# Check each file for UTF-8 BOM by reading first three bytes
	try {
		$bytes = [System.IO.File]::ReadAllBytes($file.FullName)
	}
	catch {
		Write-Host ""
		Write-Warning "Could not read $($file.Name): $($_.Exception.Message)"
		continue
	}

	$hasBOM = (
		$bytes.Length -ge 3 -and
		$bytes[0] -eq 0xEF -and
		$bytes[1] -eq 0xBB -and
		$bytes[2] -eq 0xBF
	)

	if ($hasBOM) {
		$SuccessFiles += $file.FullName
		continue
	}
	else {
		$MissingBOM++
		$FailureFiles += $file.FullName
	}
}

# Show successes only
if ($Successes) {
	if ($SuccessFiles.Count) {
		$lines = $SuccessFiles | ForEach-Object { Split-Path $_ -Leaf }
		if (-not $NoConsoleOutput) {
			foreach ($line in $lines) {
				Write-Host $line -ForegroundColor Cyan
			}
			Write-Host ""  # newline after last file
		}
	}
	else {
		$lines = @("No files with UTF-8 BOM found.")
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "No files with UTF-8 BOM found."
		}
	}

	if ($SaveResults) {
		try {
			[System.IO.File]::WriteAllText($SaveResults, ($lines -join "`n"))
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}

	exit 0
}

# Show failures only
if ($Failures) {
	if ($FailureFiles.Count) {
		$lines = $FailureFiles | ForEach-Object { Split-Path $_ -Leaf }
		if (-not $NoConsoleOutput) {
			foreach ($line in $lines) {
				Write-Host $line -ForegroundColor Yellow
			}
			Write-Host ""  # newline after last file
		}
	}
	else {
		$lines = @("No files missing UTF-8 BOM found.")
		if (-not $NoConsoleOutput) {
			Write-Host $lines[0] -ForegroundColor Cyan
			Write-Host ""
		}
	}

	if ($SaveResults) {
		try {
			[System.IO.File]::WriteAllText($SaveResults, ($lines -join "`n"))
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}

	exit 0
}

# Print successes first (normal interactive flow)
# Suppress printing already-OK files if -ConvertAll is active
if ($SuccessFiles.Count -and (-not $ConvertAll)) {
	foreach ($filePath in $SuccessFiles) {
		$fileName = Split-Path $filePath -Leaf
		Write-Host "${fileName}: UTF-8 BOM OK" -ForegroundColor Cyan
		if ($SaveResults) {
			$FileOutputLines += "${fileName}: UTF-8 BOM OK"
		}
	}
	Write-Host ""  # blank line between successes and failures
}

# Interactive processing for files missing BOM
foreach ($filePath in $FailureFiles) {
	$file = Get-Item $filePath
	$fileName = $file.Name
	if (-not $NoConsoleOutput) { Write-Host "${fileName}: UTF-8 BOM Incorrect" -ForegroundColor Yellow }

	$skipFile = $false
	while (-not $skipFile) {
		if ($ConvertAll) {
			$answer = 'Y'
		}
		else {
			$answer = (Read-Host "Convert '$($file.FullName)' to UTF-8 BOM? (Y/N)").Trim()
		}

		switch ($answer.ToUpper()) {
			'Y' {
				if ($Backup) {
					$createBackup = $true
				}
				else {
					if (-not $ConvertAll) {
						$backupAnswer = (Read-Host "Create backup for '$fileName'? (Y/N)").Trim()
						$createBackup = $backupAnswer -match '^[Yy]'
					}
					else {
						$createBackup = $false
					}
				}

				try {
					if ($createBackup -and $file) {
						$backupPath = "$($file.FullName).bak"
						Copy-Item -Path $file.FullName -Destination $backupPath -Force -ErrorAction Stop
						if (-not $NoConsoleOutput) { Write-Host "Backup created: $backupPath" -ForegroundColor Cyan }
						if ($SaveResults) {
							$FileOutputLines += "Backup created: $backupPath"
						}
					}
					elseif (-not $createBackup -and $file) {
						if (-not $NoConsoleOutput) { Write-Host "$($file.FullName): Backup skipped by user" -ForegroundColor Yellow }
						if ($SaveResults) {
							$FileOutputLines += "$($file.FullName): Backup skipped by user"
						}
					}

					$content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
					$utf8Bom = New-Object System.Text.UTF8Encoding $true
					[System.IO.File]::WriteAllText($file.FullName, $content, $utf8Bom)
					if (-not $NoConsoleOutput) { Write-Host "${fileName}: Converted to UTF-8 BOM" -ForegroundColor Green }
					if ($SaveResults) {
						$FileOutputLines += "${fileName}: Converted to UTF-8 BOM"
					}
					$Converted++
					$skipFile = $true
				}
				catch {
					if (-not $NoConsoleOutput) {
						Write-Host ""
						Write-Warning "Failed to convert $($fileName): $($_.Exception.Message)"
					}
					if ($SaveResults) {
						$FileOutputLines += "Failed to convert ${fileName}: $($_.Exception.Message)"
					}
					$skipFile = $true
				}
			}
			'N' {
				Write-Host "${fileName}: Skipped by user" -ForegroundColor Yellow
				if ($SaveResults) {
					$FileOutputLines += "${fileName}: Skipped by user"
				}
				$skipFile = $true
			}
			default {
				Write-Host "Please enter Y or N." -ForegroundColor Yellow
			}
		}
		if (-not $NoConsoleOutput) { Write-Host "" }  # blank line after each failure
	}
}

# Summary line
$summaryLine = "$ScriptName`: Analyzed $TotalFiles files: $MissingBOM missing BOM, $Converted converted."

# Display summary
if (-not $NoConsoleOutput) {
	if ($Converted) {
		Write-Host $summaryLine -ForegroundColor Green
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

	# Remove trailing blank lines
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