# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# Description:
#  - This script checks files for UTF-8 BOM formatting and optionally converts them to UTF-8 BOM

# Features:
#  - Interactive Y/N prompts for each file that is missing BOM
#  - Optional backups before conversion (-SaveBackup skips prompts)
#  - Can scan a single file or all files in a folder. Use -Recurse for subfolders
#  - Quick one-line summary at the end showing total files scanned, missing BOM, and converted files
#  - Success/failure separation in output for easier reading
#  - Correct UTF-8 BOM output in both PowerShell 5.x and 7.x
#  - Robust handling of skipped files to always display filename
#  - Warns if no .ps1 files are found in the specified path

# Optional flags:
#     -ConvertAll: Automatically convert all files without prompting
#     -Recurse: Include all .ps1 files in subfolders of the specified path
#     -SaveBackup: Automatically create backups before converting files (skips interactive prompt)
#     -ShowFailures: Only show files skipped or not converted
#     -ShowSuccesses: Only show successfully converted filenames
#     -Help / -?: Display this help message

[CmdletBinding(DefaultParameterSetName='Normal')]
param(
	[switch]$ConvertAll,
	[switch]$Help,
	[switch]$Recurse,
	[switch]$SaveBackup,
	[switch]$ShowFailures,
	[switch]$ShowSuccesses
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-ConvertAll] [-Recurse] [-SaveBackup] [-ShowSuccesses] [-ShowFailures] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -ConvertAll    Automatically convert all files without prompting" -ForegroundColor Cyan
	Write-Host "  -Recurse       Include all .ps1 files in subfolders of the specified path" -ForegroundColor Cyan
	Write-Host "  -SaveBackup    Automatically create backups before converting files (skips interactive prompt)" -ForegroundColor Cyan
	Write-Host "  -ShowFailures  Only show files skipped or not converted" -ForegroundColor Cyan
	Write-Host "  -ShowSuccesses Only show successfully converted filenames" -ForegroundColor Cyan
	Write-Host "  -Help          Display this help message" -ForegroundColor Cyan
	Write-Host "" # extra newline for readability
	exit 0
}

# Prompt user for file or folder path
$Path = Read-Host "`nEnter the full path to a script (.ps1) or a folder containing scripts"
Write-Host "" # blank line after initial user-input

# Validate path exists
if (-not (Test-Path $Path)) {
	Write-Error "Path not found: $Path"
	exit 1
}

$items = Get-Item $Path

# Include only .ps1 scripts
$files = if ($items.PSIsContainer) {
	Get-ChildItem -Path $Path -File -Recurse:$Recurse -Filter *.ps1
} else {
	if ($items.Extension -eq '.ps1') { @($items) } else { @() }
}

# Quick check for no .ps1 files
if (-not $files -or $files.Count -eq 0) {
	Write-Host "No PowerShell (.ps1) files found in '$Path'. Exiting..." -ForegroundColor Red
	exit 1
}

# Counters for statistics
$TotalFiles = 0
$MissingBOM = 0
$Converted = 0

# Arrays to separate successes and failures for clean output
$Successes = @()
$Failures = @()

foreach ($file in $files) {
	$TotalFiles++

	# Check each file for UTF-8 BOM by reading first three bytes
	$bytes = [System.IO.File]::ReadAllBytes($file.FullName)
	$hasBOM = (
		$bytes.Length -ge 3 -and
		$bytes[0] -eq 0xEF -and
		$bytes[1] -eq 0xBB -and
		$bytes[2] -eq 0xBF
	)

	if ($hasBOM) {
		$Successes += $file.Name
		continue
	} else {
		$MissingBOM++
		$Failures += $file.Name
	}
}

# Show successes only
if ($ShowSuccesses) {
	if ($Successes.Count) {
		foreach ($s in $Successes) {
			Write-Host $s -ForegroundColor Cyan
		}
	} else {
		Write-Host "No files with UTF-8 BOM found." -ForegroundColor Yellow
	}
	Write-Host "" # newline after last file
	exit 0
}

# Show failures only
if ($ShowFailures) {
	if ($Failures.Count) {
		foreach ($f in $Failures) {
			Write-Host $f -ForegroundColor Yellow
		}
	} else {
		Write-Host "No files missing UTF-8 BOM found." -ForegroundColor Cyan
	}
	Write-Host "" # newline after last file
	exit 0
}

# Print successes first (normal interactive flow)
# Suppress printing already-OK files if -ConvertAll is active
if ($Successes.Count -and (-not $ConvertAll)) {
	foreach ($s in $Successes) {
		Write-Host "${s}: UTF-8 BOM OK" -ForegroundColor Cyan
	}
	Write-Host "" # blank line between successes and failures
}

# Interactive processing for files missing BOM
foreach ($fileName in $Failures) {
	$file = $files | Where-Object { $_.Name -eq $fileName } | Select-Object -First 1
	Write-Host "${fileName}: UTF-8 BOM Incorrect" -ForegroundColor Yellow

	$skipFile = $false
	while (-not $skipFile) {
		if ($ConvertAll) { $answer = 'Y' } else {
			$answer = (Read-Host "Convert '$($file.FullName)' to UTF-8 BOM? (Y/N)").Trim()
		}

		switch ($answer.ToUpper()) {
			'Y' {
				if ($SaveBackup) {
					$backup = $true
				} else {
					if (-not $ConvertAll) {
						$backupAnswer = (Read-Host "Create backup for '$fileName'? (Y/N)").Trim()
						$backup = $backupAnswer -match '^[Yy]'
					} else {
						$backup = $false
					}
				}

				if ($backup -and $file) {
					$backupPath = "$($file.FullName).bak"
					Copy-Item -Path $file.FullName -Destination $backupPath -Force
					Write-Host "Backup created: $backupPath" -ForegroundColor Cyan
				} elseif (-not $backup -and $file) {
					Write-Host "$($file.FullName): Backup skipped by user" -ForegroundColor Yellow
				}

				if ($file) {
					$content = Get-Content -Path $file.FullName -Raw
					$utf8Bom = New-Object System.Text.UTF8Encoding $true
					[System.IO.File]::WriteAllText($file.FullName, $content, $utf8Bom)
				}

				Write-Host "${fileName}: Converted to UTF-8 BOM" -ForegroundColor Green
				$Converted++
				$skipFile = $true
			}
			'N' {
				Write-Host "${fileName}: Skipped by user" -ForegroundColor Yellow
				$skipFile = $true
			}
			default {
				Write-Host "Please enter Y or N." -ForegroundColor Yellow
			}
		}
		Write-Host "" # blank line after each failure
	}
}

# Summary
if ($Converted) {
	Write-Host "Analyzed $TotalFiles files: $MissingBOM missing BOM, $Converted converted." -ForegroundColor Green
} else {
	Write-Host "Analyzed $TotalFiles files: $MissingBOM missing BOM, $Converted converted." -ForegroundColor Yellow
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.