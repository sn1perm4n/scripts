# This script deletes all but the most recent folder that starts with the character "B" in a specific directory

# Specify the directory to process
$programfilesx86BattlenetFolder = 'C:\Program Files (x86)\Battle.net'

# Check if the directory exists
if (Test-Path -Path $programfilesx86BattlenetFolder) {
	try {
		# Get all folders in the directory that start with "B"
		$foldersStartingWithB = Get-ChildItem -Path $programfilesx86BattlenetFolder -Directory | Where-Object { $_.Name -clike "B*" }
		# Guard clause that activates and exits if no "B" folders exist
		if (-not $foldersStartingWithB) {
			Write-Warning "No folders starting with 'B' found in '$programfilesx86BattlenetFolder'."
			return
		}
		# Find the most recently modified folder that starts with "B"
		$latestBFolder = $foldersStartingWithB | Sort-Object LastWriteTime -Descending | Select-Object -First 1
		# Output which folder is being kept
		Write-Host "Keeping folder: $($latestBFolder.Name)"
		# Track if any deletions happen
		$deleted = $false
		# Delete all "B" folders with the exception of the newest
		foreach ($folder in $foldersStartingWithB) {
			if ($latestBFolder -and $folder.FullName -ne $latestBFolder.FullName) {
				Write-Host "Deleting folder: $($folder.FullName)"
				Remove-Item -Path $folder.FullName -Recurse -Force
				$deleted = $true
			}
		}
		if ($deleted) {
			Write-Host "Successfully deleted all 'B' folders with the exception of the newest in '$programfilesx86BattlenetFolder'."
		}
		else {
			Write-Host "Only one folder starting with 'B' exists. Nothing deleted."
		}
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$programfilesx86BattlenetFolder': $($_.Exception.Message)."
	}
}
else {
	Write-Warning "The directory '$programfilesx86BattlenetFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.