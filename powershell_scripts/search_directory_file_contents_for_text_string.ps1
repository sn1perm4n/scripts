# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script searches a user-defined directory for a user-defined text string

# Optional flags:
#     -CaseSensitive: Enables case-sensitive search
#     -Exact: Match only lines where the entire line equals the search text
#     -Filenames: Show unique filenames only instead of full table output
#     -LinesAbove <N>: Include N lines of context above each match
#     -LinesBelow <N>: Include N lines of context below each match
#     -Recurse: Search subdirectories recursively
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -ShowLines: Show full line content grouped by file with line numbers (replaces default table output)
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$CaseSensitive,
	[switch]$Exact,
	[switch]$Filenames,
	[int]$LinesAbove = 0,
	[int]$LinesBelow = 0,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$ShowLines,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-CaseSensitive] [-Exact] [-Filenames] [-LinesAbove <N>] [-LinesBelow <N>] [-Recurse] [-SaveResults <PATH>] [-ShowLines] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -CaseSensitive       Enables case-sensitive search" -ForegroundColor Cyan
	Write-Host "  -Exact               Match only lines where the entire line equals the search text" -ForegroundColor Cyan
	Write-Host "  -Filenames           Show unique filenames only instead of full table output" -ForegroundColor Cyan
	Write-Host "  -LinesAbove <N>      Include N lines of context above each match" -ForegroundColor Cyan
	Write-Host "  -LinesBelow <N>      Include N lines of context below each match" -ForegroundColor Cyan
	Write-Host "  -Recurse             Search subdirectories recursively" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
	Write-Host "  -ShowLines           Show full line content grouped by file with line numbers (replaces default table output)" -ForegroundColor Cyan
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

# Prompt user for directory path
$searchPath = Read-Host "Enter the directory path to search"

# Validate directory exists before proceeding
if (-not (Test-Path -Path $searchPath -PathType Container)) {
	Write-Error "The directory '$searchPath' does not exist."
	exit 1
}

# Prompt user for search text only after path validation
$searchText = Read-Host "`nEnter the text string to search for"

try {
	Write-Host "`nSearching for '$searchText' in '$searchPath'..." -ForegroundColor Cyan

	$getChildItemParams = @{
		Path = $searchPath
		File = $true
		Recurse = $Recurse
		ErrorAction = 'Stop'
	}

	$escapedText = [regex]::Escape($searchText)
	$pattern = if ($Exact) { "^\s*$escapedText\s*$" } else { $escapedText }

	$selectStringParams = @{
		Pattern = $pattern
		CaseSensitive = $CaseSensitive
		ErrorAction = 'Stop'
	}

	$Results = Get-ChildItem @getChildItemParams | Select-String @selectStringParams

	if ($Results) {
		if ($Filenames) {
			# Show unique filenames only as a clean list
			# (-ShowLines, -LinesAbove, and -LinesBelow are ignored in -Filenames mode)
			$uniqueFiles = $Results | Select-Object -ExpandProperty Filename -Unique
			Write-Host ""
			$uniqueFiles | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }

			$summaryLine = "$($uniqueFiles.Count) file(s) found containing '$searchText'."
			Write-Host "`n$summaryLine" -ForegroundColor Green

			if ($SaveResults) {
				$outputLines = $uniqueFiles + @("", $summaryLine)
				try {
					$outputString = ($outputLines -join "`n")
					[System.IO.File]::WriteAllText($SaveResults, $outputString)
					Write-Host "`nResults saved to text file: $SaveResults" -ForegroundColor Green
				}
				catch {
					Write-Host ""
					Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
				}
			}
		}
		else {
			$useContext = ($LinesAbove -gt 0 -or $LinesBelow -gt 0)

			if ($useContext) {
				# Group results by file for context display
				$resultsByFile = $Results | Group-Object Path

				foreach ($fileGroup in $resultsByFile) {
					$fileLines = @(Get-Content -Path $fileGroup.Name)
					$totalLines = $fileLines.Count

					Write-Host "`n$($fileGroup.Name):" -ForegroundColor Cyan

					foreach ($match in $fileGroup.Group) {
						$matchLineIndex = $match.LineNumber - 1  # convert to 0-based
						$contextStart = [math]::Max(0, $matchLineIndex - $LinesAbove)
						$contextEnd = [math]::Min($totalLines - 1, $matchLineIndex + $LinesBelow)

						for ($i = $contextStart; $i -le $contextEnd; $i++) {
							$lineNum = $i + 1  # display as 1-based
							$lineText = $fileLines[$i]
							if ($i -eq $matchLineIndex) {
								Write-Host "  Line $lineNum [MATCH]: $($lineText.Trim())" -ForegroundColor Yellow
							}
							else {
								Write-Host "  Line $lineNum        : $($lineText.Trim())" -ForegroundColor Cyan
							}
						}
						Write-Host ""
					}
				}

				$fileCount = ($Results | Select-Object -ExpandProperty Path -Unique | Measure-Object).Count
				$summaryLine = "$($Results.Count) match(es) found across $fileCount file(s)."
				Write-Host $summaryLine -ForegroundColor Green
			}
			elseif ($ShowLines) {
				# Show full line content grouped by file with line numbers
				$resultsByFile = $Results | Group-Object Path

				foreach ($fileGroup in $resultsByFile) {
					Write-Host "`n$($fileGroup.Name):" -ForegroundColor Cyan
					foreach ($match in $fileGroup.Group) {
						Write-Host "  Line $($match.LineNumber): $($match.Line.Trim())" -ForegroundColor Yellow
					}
				}

				$fileCount = ($Results | Select-Object -ExpandProperty Path -Unique | Measure-Object).Count
				$summaryLine = "$($Results.Count) match(es) found across $fileCount file(s)."
				Write-Host "`n$summaryLine" -ForegroundColor Green
			}
			else {
				$Results | Select-Object Path, LineNumber, Line | Format-Table -AutoSize

				$fileCount = ($Results | Select-Object -ExpandProperty Path -Unique | Measure-Object).Count
				$summaryLine = "$($Results.Count) match(es) found across $fileCount file(s)."
				Write-Host $summaryLine -ForegroundColor Green
			}

			if ($SaveResults) {
				$outputLines = @()

				if ($useContext) {
					$resultsByFile = $Results | Group-Object Path
					foreach ($fileGroup in $resultsByFile) {
						$fileLines = @(Get-Content -Path $fileGroup.Name)
						$totalLines = $fileLines.Count
						$outputLines += "$($fileGroup.Name):"

						foreach ($match in $fileGroup.Group) {
							$matchLineIndex = $match.LineNumber - 1
							$contextStart = [math]::Max(0, $matchLineIndex - $LinesAbove)
							$contextEnd = [math]::Min($totalLines - 1, $matchLineIndex + $LinesBelow)

							for ($i = $contextStart; $i -le $contextEnd; $i++) {
								$lineNum = $i + 1
								$lineText = $fileLines[$i]
								if ($i -eq $matchLineIndex) {
									$outputLines += "  Line $lineNum [MATCH]: $($lineText.Trim())"
								}
								else {
									$outputLines += "  Line $lineNum        : $($lineText.Trim())"
								}
							}
							$outputLines += ""
						}
					}
				}
				elseif ($ShowLines) {
					$resultsByFile = $Results | Group-Object Path
					foreach ($fileGroup in $resultsByFile) {
						$outputLines += "$($fileGroup.Name):"
						foreach ($match in $fileGroup.Group) {
							$outputLines += "  Line $($match.LineNumber): $($match.Line.Trim())"
						}
						$outputLines += ""
					}
				}
				else {
					foreach ($result in $Results) {
						$outputLines += "Path: $($result.Path)"
						$outputLines += "Line $($result.LineNumber): $($result.Line.Trim())"
					}
				}

				while ($outputLines[-1] -eq '') {
					$outputLines = $outputLines[0..($outputLines.Count - 2)]
				}

				$outputLines += ""
				$outputLines += $summaryLine

				try {
					$outputString = ($outputLines -join "`n")
					[System.IO.File]::WriteAllText($SaveResults, $outputString)
					Write-Host "`nResults saved to text file: $SaveResults" -ForegroundColor Green
				}
				catch {
					Write-Host ""
					Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
				}
			}
		}
	}
	else {
		Write-Host "`nNo matches found." -ForegroundColor Yellow
	}
}
catch {
	Write-Error "An error occurred during the search: $($_.Exception.Message)"
	exit 1
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.