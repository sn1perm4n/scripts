# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script compares files between two directories or two individual files by name and size in bytes, highlighting matches, differences, and files unique to each directory

# Optional flags:
#     -Different: Only show files that differ or are unique to one directory
#     -Filenames: Show filenames only instead of full paths (useful with -Recurse)
#     -Identical: Only show files that match between both directories
#     -NoConsoleOutput: Suppress console output (requires -Path1, -Path2, and -SaveResults)
#     -Path1 <PATH>: Path to the first file or folder (prompts if not specified)
#     -Path2 <PATH>: Path to the second file or folder (prompts if not specified)
#     -Recurse: Include files in subdirectories (only applicable when comparing directories)
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Different,
	[switch]$Filenames,
	[switch]$Identical,
	[switch]$NoConsoleOutput,
	[string]$Path1,
	[string]$Path2,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Different] [-Filenames] [-Identical] [-NoConsoleOutput] [-Path1 <PATH>] [-Path2 <PATH>] [-Recurse] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Different           Only show files that differ or are unique to one directory" -ForegroundColor Cyan
	Write-Host "  -Filenames           Show filenames only instead of full paths (useful with -Recurse)" -ForegroundColor Cyan
	Write-Host "  -Identical           Only show files that match between both directories" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -Path1, -Path2, and -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Path1 <PATH>        Path to the first file or folder (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Path2 <PATH>        Path to the second file or folder (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Recurse             Include files in subdirectories (only applicable when comparing directories)" -ForegroundColor Cyan
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

# -NoConsoleOutput requires -Path1, -Path2, and -SaveResults, since without both paths
# this script can still block on interactive prompts with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not $Path1 -or -not $Path2 -or -not $SaveResults)) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -Path1, -Path2, and -SaveResults."
	exit 1
}

# Prompt user for both paths if not specified
if (-not $Path1) {
	$Path1 = Read-Host "`nEnter the full path to the first file or folder"
}

if (-not (Test-Path -Path $Path1)) {
	$errorMessage = "Path not found: $Path1"
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

if (-not $Path2) {
	$Path2 = Read-Host "`nEnter the full path to the second file or folder"
}

if (-not (Test-Path -Path $Path2)) {
	$errorMessage = "Path not found: $Path2"
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

$item1st = Get-Item $Path1
$item2nd = Get-Item $Path2

# Initialize output lines
$FileOutputLines = @()

# Handle file vs directory mismatch
if ($item1st.PSIsContainer -ne $item2nd.PSIsContainer) {
	$errorMessage = "Cannot compare a file with a directory."
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

if (-not $NoConsoleOutput) { Write-Host "`nComparing...`n" -ForegroundColor Cyan }

# Compare two individual files
if (-not $item1st.PSIsContainer) {
	if ($item1st.Length -eq $item2nd.Length) {
		$line = "$ScriptName`: IDENTICAL:  $($item1st.Name) ($($item1st.Length) bytes)"
		if (-not $NoConsoleOutput) { Write-Host $line -ForegroundColor Green }
	}
	else {
		$line = "$ScriptName`: DIFFERENT:  $($item1st.Name) vs $($item2nd.Name) (1st: $($item1st.Length) bytes | 2nd: $($item2nd.Length) bytes)"
		if (-not $NoConsoleOutput) { Write-Host $line -ForegroundColor Yellow }
	}
	if ($SaveResults) { $FileOutputLines += $line }
}
else {
	# Compare two directories
	$files1st = Get-ChildItem -Path $Path1 -File -Recurse:$Recurse
	$files2nd = Get-ChildItem -Path $Path2 -File -Recurse:$Recurse

	if ($files1st.Count -eq 0) {
		$warningMessage = "$ScriptName`: No files found in: $Path1"
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

	if ($files2nd.Count -eq 0) {
		$warningMessage = "$ScriptName`: No files found in: $Path2"
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

	# Build lookup hashtable for 2nd directory by full path relative to root
	$lookup2nd = @{}
	foreach ($file in $files2nd) {
		$relPath = $file.FullName.Substring($Path2.Length).TrimStart('\')
		$lookup2nd[$relPath] = $file
	}

	# Initialize counters
	$identicalCount = 0
	$differentCount = 0
	$onlyIn1stCount = 0
	$onlyIn2ndCount = 0

	# Track the last displayed and last saved line types independently to add blank lines between groups
	$lastLineType = ""
	$lastSavedType = ""

	# Compare files in 1st against 2nd
	foreach ($file1st in $files1st) {
		$relPath = $file1st.FullName.Substring($Path1.Length).TrimStart('\')
		$displayName = if ($Filenames) { $file1st.Name } else { $relPath }

		if ($lookup2nd.ContainsKey($relPath)) {
			$file2nd = $lookup2nd[$relPath]
			if ($file1st.Length -eq $file2nd.Length) {
				$line = "IDENTICAL:     $displayName ($($file1st.Length) bytes)"
				if (-not $Different) {
					if (-not $NoConsoleOutput) {
						if ($lastLineType -ne "" -and $lastLineType -ne "IDENTICAL") {
							Write-Host ""
						}
						Write-Host $line -ForegroundColor Green
					}
					if ($SaveResults -and $lastSavedType -ne "" -and $lastSavedType -ne "IDENTICAL") {
						$FileOutputLines += ""
					}
					if ($SaveResults) { $FileOutputLines += $line }
					$lastLineType  = "IDENTICAL"
					$lastSavedType = "IDENTICAL"
				}
				$identicalCount++
			}
			else {
				if ($Filenames) {
					$line = "DIFFERENT:     $displayName (1st: $($file1st.Length) bytes | 2nd: $($file2nd.Length) bytes)"
				}
				else {
					$line = "DIFFERENT:     1st: $($file1st.FullName) ($($file1st.Length) bytes) | 2nd: $($file2nd.FullName) ($($file2nd.Length) bytes)"
				}
				if (-not $Identical) {
					if (-not $NoConsoleOutput) {
						if ($lastLineType -ne "" -and $lastLineType -ne "DIFFERENT") {
							Write-Host ""
						}
						Write-Host $line -ForegroundColor Yellow
					}
					if ($SaveResults -and $lastSavedType -ne "" -and $lastSavedType -ne "DIFFERENT") {
						$FileOutputLines += ""
					}
					if ($SaveResults) { $FileOutputLines += $line }
					$lastLineType  = "DIFFERENT"
					$lastSavedType = "DIFFERENT"
				}
				$differentCount++
			}
		}
		else {
			if ($Filenames) {
				$line = "ONLY IN 1ST:   $displayName ($($file1st.Length) bytes)"
			}
			else {
				$line = "ONLY IN 1ST:   $($file1st.FullName) ($($file1st.Length) bytes)"
			}
			if (-not $Identical) {
				if (-not $NoConsoleOutput) {
					if ($lastLineType -ne "" -and $lastLineType -ne "ONLY IN 1ST") {
						Write-Host ""
					}
					Write-Host $line -ForegroundColor Cyan
				}
				if ($SaveResults -and $lastSavedType -ne "" -and $lastSavedType -ne "ONLY IN 1ST") {
					$FileOutputLines += ""
				}
				if ($SaveResults) { $FileOutputLines += $line }
				$lastLineType  = "ONLY IN 1ST"
				$lastSavedType = "ONLY IN 1ST"
			}
			$onlyIn1stCount++
		}
	}

	# Find files only in 2nd
	foreach ($file2nd in $files2nd) {
		$relPath = $file2nd.FullName.Substring($Path2.Length).TrimStart('\')
		if (-not $lookup2nd.ContainsKey($relPath) -or -not ($files1st | Where-Object { $_.FullName.Substring($Path1.Length).TrimStart('\') -eq $relPath })) {
			if ($Filenames) {
				$line = "ONLY IN 2ND:   $($file2nd.Name) ($($file2nd.Length) bytes)"
			}
			else {
				$line = "ONLY IN 2ND:   $($file2nd.FullName) ($($file2nd.Length) bytes)"
			}
			if (-not $Identical) {
				if (-not $NoConsoleOutput) {
					if ($lastLineType -ne "" -and $lastLineType -ne "ONLY IN 2ND") {
						Write-Host ""
					}
					Write-Host $line -ForegroundColor Cyan
				}
				if ($SaveResults -and $lastSavedType -ne "" -and $lastSavedType -ne "ONLY IN 2ND") {
					$FileOutputLines += ""
				}
				if ($SaveResults) { $FileOutputLines += $line }
				$lastLineType  = "ONLY IN 2ND"
				$lastSavedType = "ONLY IN 2ND"
			}
			$onlyIn2ndCount++
		}
	}

	# Summary
	$summaryLine = "$ScriptName`: Comparison complete. Identical: $identicalCount, Different: $differentCount, Only in 1st: $onlyIn1stCount, Only in 2nd: $onlyIn2ndCount."
	if (-not $NoConsoleOutput) {
		if ($Different -and $differentCount -eq 0 -and $onlyIn1stCount -eq 0 -and $onlyIn2ndCount -eq 0) {
			Write-Host $summaryLine -ForegroundColor Cyan
		}
		else {
			Write-Host "`n$summaryLine" -ForegroundColor Cyan
		}
	}
	if ($SaveResults) {
		$FileOutputLines += ""
		$FileOutputLines += $summaryLine
	}
}

# Save results to text file if requested
if ($SaveResults) {
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

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.