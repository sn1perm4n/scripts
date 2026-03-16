# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# Description:
#  - This script searches a user-defined directory for a user-defined text string

# Features:
#  - Searches all files in a directory recursively
#  - Displays matching file path, line number, and line content in table format
#  - Displays a summary of total matches and files found
#  - Optional saving of results to a text file

# Optional flags:
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt") - must be specified last
#     -Help / -?: Display this help message

[CmdletBinding()]
param (
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"") - must be specified last" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host "" # extra newline for readability
	exit 0
}

# Prompt user for directory path
$searchPath = Read-Host "`nEnter the directory path to search"

# Validate directory exists before proceeding
if (-not (Test-Path -Path $searchPath -PathType Container)) {
	Write-Error "The directory '$searchPath' does not exist."
	exit 1
}

# Prompt user for search text only after path validation
$searchText = Read-Host "`nEnter the text string to search for"

try {
	Write-Host "`nSearching for '$searchText' in '$searchPath'..." -ForegroundColor Cyan
	$Results = Get-ChildItem -Path $searchPath -Recurse -File -ErrorAction Stop |
		Select-String -Pattern $searchText -SimpleMatch -ErrorAction Stop

	if ($Results) {
		$Results | Select-Object Path, LineNumber, Line |
			Format-Table -AutoSize
		Write-Host "$($Results.Count) match(es) found across $($Results | Select-Object -ExpandProperty Path -Unique | Measure-Object | Select-Object -ExpandProperty Count) file(s)." -ForegroundColor Cyan

		if ($SaveResults) {
			$outputLines = @()
			foreach ($result in $Results) {
				$outputLines += "Path: $($result.Path)"
				$outputLines += "Line $($result.LineNumber): $($result.Line.Trim())"
			}
			# Remove trailing blank lines
			while ($outputLines[-1] -eq '') {
				$outputLines = $outputLines[0..($outputLines.Count - 2)]
			}
			$outputLines += ""
			$outputLines += "$($Results.Count) match(es) found across $($Results | Select-Object -ExpandProperty Path -Unique | Measure-Object | Select-Object -ExpandProperty Count) file(s)."
			$outputString = ($outputLines -join "`n")
			[System.IO.File]::WriteAllText($SaveResults, $outputString)
			Write-Host "`nResults saved to text file: $SaveResults" -ForegroundColor Green
		}
	}
	else {
		Write-Host "`nNo matches found." -ForegroundColor Yellow
	}
}
catch {
	Write-Error "An error occurred during the search: $($_.Exception.Message)."
	exit 1
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.