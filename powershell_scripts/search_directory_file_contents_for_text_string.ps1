# This script searches a user-defined directory for a user-defined text string.

# Prompt user for directory path
$searchPath = Read-Host "Enter the directory path to search"

# Validate directory exists before proceeding
if (-not (Test-Path -Path $searchPath -PathType Container)) {
	Write-Error "The directory '$searchPath' does not exist."
	exit 1
}

# Prompt user for search text only after path validation
$searchText = Read-Host "Enter the text string to search for"

try {
	Write-Host "Searching for '$searchText' in '$searchPath'..." -ForegroundColor Cyan

	$Results = Get-ChildItem -Path $searchPath -Recurse -File -ErrorAction Stop |
		Select-String -Pattern $searchText -ErrorAction Stop

	if ($Results) {
		$Results | Select-Object Path, LineNumber, Line |
			Format-Table -AutoSize
	}
	else {
		Write-Host "No matches found." -ForegroundColor Yellow
	}
}
catch {
	Write-Error "An error occurred during the search: $($_.Exception.Message)."
	exit 1
}

# End.