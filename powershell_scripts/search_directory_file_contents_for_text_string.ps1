# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script searches a user-defined directory for a user-defined text string

# Optional flags:
#     -CaseSensitive: Enables case-sensitive search
#     -Filenames: Show unique filenames only instead of full table output
#     -Recurse: Search subdirectories recursively
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$CaseSensitive,
	[switch]$Filenames,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-CaseSensitive] [-Filenames] [-Recurse] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -CaseSensitive       Enables case-sensitive search" -ForegroundColor Cyan
	Write-Host "  -Filenames           Show unique filenames only instead of full table output" -ForegroundColor Cyan
	Write-Host "  -Recurse             Search subdirectories recursively" -ForegroundColor Cyan
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

	$selectStringParams = @{
		Pattern = $searchText
		SimpleMatch = $true
		CaseSensitive = $CaseSensitive
		ErrorAction = 'Stop'
	}

	$Results = Get-ChildItem @getChildItemParams | Select-String @selectStringParams

	if ($Results) {
		if ($Filenames) {
			# Show unique filenames only as a clean list
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
			$Results | Select-Object Path, LineNumber, Line | Format-Table -AutoSize

			$summaryLine = "$($Results.Count) match(es) found across $($Results | Select-Object -ExpandProperty Path -Unique | Measure-Object | Select-Object -ExpandProperty Count) file(s)."
			Write-Host $summaryLine -ForegroundColor Green

			if ($SaveResults) {
				$outputLines = @()
				foreach ($result in $Results) {
					$outputLines += "Path: $($result.Path)"
					$outputLines += "Line $($result.LineNumber): $($result.Line.Trim())"
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