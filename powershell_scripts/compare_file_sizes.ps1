# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script compares files between two directories or two individual files by name and size in bytes, highlighting matches, differences, and files unique to each directory

# Optional flags:
#     -Different: Only show files that differ or are unique to one directory
#     -Filenames: Show filenames only instead of full paths (useful with -Recurse)
#     -Identical: Only show files that match between both directories
#     -Recurse: Include files in subdirectories (only applicable when comparing directories)
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Different,
	[switch]$Filenames,
	[switch]$Identical,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Different] [-Filenames] [-Identical] [-Recurse] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Different           Only show files that differ or are unique to one directory" -ForegroundColor Cyan
	Write-Host "  -Filenames           Show filenames only instead of full paths (useful with -Recurse)" -ForegroundColor Cyan
	Write-Host "  -Identical           Only show files that match between both directories" -ForegroundColor Cyan
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

# Prompt user for both paths
$Path1st = Read-Host "`nEnter the full path to the first file or directory"

if (-not (Test-Path -Path $Path1st)) {
	Write-Host ""
	Write-Error "Path not found: $Path1st"
	exit 1
}

$Path2nd = Read-Host "`nEnter the full path to the second file or directory"

if (-not (Test-Path -Path $Path2nd)) {
	Write-Host ""
	Write-Error "Path not found: $Path2nd"
	exit 1
}

$item1st = Get-Item $Path1st
$item2nd = Get-Item $Path2nd

# Initialize output lines
$FileOutputLines = @()

# Handle file vs directory mismatch
if ($item1st.PSIsContainer -ne $item2nd.PSIsContainer) {
	Write-Host ""
	Write-Error "Cannot compare a file with a directory."
	exit 1
}

Write-Host "`nComparing...`n" -ForegroundColor Cyan

# Compare two individual files
if (-not $item1st.PSIsContainer) {
	if ($item1st.Length -eq $item2nd.Length) {
		$line = "IDENTICAL:  $($item1st.Name) ($($item1st.Length) bytes)"
		Write-Host $line -ForegroundColor Green
	}
	else {
		$line = "DIFFERENT:  $($item1st.Name) vs $($item2nd.Name) (1st: $($item1st.Length) bytes | 2nd: $($item2nd.Length) bytes)"
		Write-Host $line -ForegroundColor Yellow
	}
	if ($SaveResults) { $FileOutputLines += $line }
}
else {
	# Compare two directories
	$files1st = Get-ChildItem -Path $Path1st -File -Recurse:$Recurse
	$files2nd = Get-ChildItem -Path $Path2nd -File -Recurse:$Recurse

	if ($files1st.Count -eq 0) {
		Write-Host "No files found in: $Path1st" -ForegroundColor Yellow
		exit 0
	}

	if ($files2nd.Count -eq 0) {
		Write-Host "No files found in: $Path2nd" -ForegroundColor Yellow
		exit 0
	}

	# Build lookup hashtable for 2nd directory by full path relative to root
	$lookup2nd = @{}
	foreach ($file in $files2nd) {
		$relPath = $file.FullName.Substring($Path2nd.Length).TrimStart('\')
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
		$relPath = $file1st.FullName.Substring($Path1st.Length).TrimStart('\')
		$displayName = if ($Filenames) { $file1st.Name } else { $relPath }

		if ($lookup2nd.ContainsKey($relPath)) {
			$file2nd = $lookup2nd[$relPath]
			if ($file1st.Length -eq $file2nd.Length) {
				$line = "IDENTICAL:     $displayName ($($file1st.Length) bytes)"
				if (-not $Different) {
					if ($lastLineType -ne "" -and $lastLineType -ne "IDENTICAL") {
						Write-Host ""
					}
					if ($SaveResults -and $lastSavedType -ne "" -and $lastSavedType -ne "IDENTICAL") {
						$FileOutputLines += ""
					}
					Write-Host $line -ForegroundColor Green
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
					if ($lastLineType -ne "" -and $lastLineType -ne "DIFFERENT") {
						Write-Host ""
					}
					if ($SaveResults -and $lastSavedType -ne "" -and $lastSavedType -ne "DIFFERENT") {
						$FileOutputLines += ""
					}
					Write-Host $line -ForegroundColor Yellow
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
				if ($lastLineType -ne "" -and $lastLineType -ne "ONLY IN 1ST") {
					Write-Host ""
				}
				if ($SaveResults -and $lastSavedType -ne "" -and $lastSavedType -ne "ONLY IN 1ST") {
					$FileOutputLines += ""
				}
				Write-Host $line -ForegroundColor Cyan
				if ($SaveResults) { $FileOutputLines += $line }
				$lastLineType  = "ONLY IN 1ST"
				$lastSavedType = "ONLY IN 1ST"
			}
			$onlyIn1stCount++
		}
	}

	# Find files only in 2nd
	foreach ($file2nd in $files2nd) {
		$relPath = $file2nd.FullName.Substring($Path2nd.Length).TrimStart('\')
		if (-not $lookup2nd.ContainsKey($relPath) -or -not ($files1st | Where-Object { $_.FullName.Substring($Path1st.Length).TrimStart('\') -eq $relPath })) {
			if ($Filenames) {
				$line = "ONLY IN 2ND:   $($file2nd.Name) ($($file2nd.Length) bytes)"
			}
			else {
				$line = "ONLY IN 2ND:   $($file2nd.FullName) ($($file2nd.Length) bytes)"
			}
			if (-not $Identical) {
				if ($lastLineType -ne "" -and $lastLineType -ne "ONLY IN 2ND") {
					Write-Host ""
				}
				if ($SaveResults -and $lastSavedType -ne "" -and $lastSavedType -ne "ONLY IN 2ND") {
					$FileOutputLines += ""
				}
				Write-Host $line -ForegroundColor Cyan
				if ($SaveResults) { $FileOutputLines += $line }
				$lastLineType  = "ONLY IN 2ND"
				$lastSavedType = "ONLY IN 2ND"
			}
			$onlyIn2ndCount++
		}
	}

	# Summary
	$summaryLine = "Comparison complete. Identical: $identicalCount, Different: $differentCount, Only in 1st: $onlyIn1stCount, Only in 2nd: $onlyIn2ndCount."
	if ($Different -and $differentCount -eq 0 -and $onlyIn1stCount -eq 0 -and $onlyIn2ndCount -eq 0) {
		Write-Host $summaryLine -ForegroundColor Cyan
	}
	else {
		Write-Host "`n$summaryLine" -ForegroundColor Cyan
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
		Write-Host "`nResults saved to text file: $SaveResults" -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.