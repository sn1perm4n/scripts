# This script deletes all but the most recent folder in a specific folder

# Specify the directory to process (the name of this directory may be different on your computer)
$appdataLocalMremotengFolder = 'C:\Users\<PROFILE>\AppData\Local\mRemoteNG\mRemoteNG.exe_Url_pjpxdehxpaaorqg2thmuhl11a34i3ave'

# Check if the directory exists
if (Test-Path -Path $appdataLocalMremotengFolder) {
	try {
		# Get all folders within the directory
		$items = Get-ChildItem -Path $appdataLocalMremotengFolder -Directory
		# Guard clause that activates and exits if there's only 0 or 1 folder
		if ($items.Count -le 1) {
			$count = $items.Count
			Write-Warning "The directory '$appdataLocalMremotengFolder' exists but contains $count folder$(if ($count -ne 1) {'s'})."
			return
		}
		# Sort the items by LastWriteTime in descending order
		$sortedItems = $items | Sort-Object LastWriteTime -Descending
		# Remove all but the most recent item from the list
		$itemsToDelete = $sortedItems | Select-Object -Skip 1
		$latestItem = $sortedItems | Select-Object -First 1
		# Output which folder is being kept
		Write-Host "Keeping folder: $($latestItem.FullName)"
		# Track if any deletions happen
		$deleted = $false
		if ($itemsToDelete) {
			Write-Host "Deleting the following items:"
			# Delete all items except the most recent
			foreach ($itemToDelete in $itemsToDelete) {
				Write-Host "Deleting folder: $($itemToDelete.FullName)"
				Remove-Item -Path $itemToDelete.FullName -Recurse -Force
				$deleted = $true
			}
		}
		if ($deleted) {
			Write-Host "Successfully deleted all folders with the exception of the newest in '$appdataLocalMremotengFolder'."
		}
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$appdataLocalMremotengFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$appdataLocalMremotengFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.