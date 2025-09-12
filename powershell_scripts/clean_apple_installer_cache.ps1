# This script deletes all folders that start with the character "A" with the exception of the newest one in a specific directory

# Specify the directory to process
$appleInstallerCacheFolder = 'C:\ProgramData\Apple\Installer Cache'

# Check if the directory exists
if (Test-Path -Path $appleInstallerCacheFolder) {
	try {
		# Get all folders in the directory that start with "A"
		$foldersStartingWithA = Get-ChildItem -Path $appleInstallerCacheFolder -Directory | Where-Object { $_.Name -clike "A*" }
		# Guard clause that activates and exits if no "A" folders exist
		if (-not $foldersStartingWithA) {
			Write-Warning "No folders starting with 'A' found in '$appleInstallerCacheFolder'."
			return
		}
		# Find the most recently modified folder that starts with "A"
		$latestAFolder = $foldersStartingWithA | Sort-Object LastWriteTime -Descending | Select-Object -First 1
		# Output which folder is being kept
		Write-Host "Keeping folder: $($latestAFolder.Name)"
		# Track if any deletions happen
		$deleted = $false
		# Delete all "A" folders with the exception of the newest
		foreach ($folder in $foldersStartingWithA) {
			if ($folder.FullName -ne $latestAFolder.FullName) {
				Write-Host "Deleting folder: $($folder.FullName)"
				Remove-Item -Path $folder.FullName -Recurse -Force
				$deleted = $true
			}
		}
		if ($deleted) {
			Write-Host "Successfully deleted all 'A' folders with the exception of the newest in '$appleInstallerCacheFolder'."
		}
		else {
			Write-Host "Only one folder starting with 'A' exists. Nothing deleted."
		}
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$appleInstallerCacheFolder': $($_.Exception.Message)."
	}
}
else {
	Write-Warning "The directory '$appleInstallerCacheFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.