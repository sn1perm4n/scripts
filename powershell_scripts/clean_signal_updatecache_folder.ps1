# This script deletes the contents of a specific folder

# Specify the directory to process
$appdataRoamingSignalFolder = 'C:\Users\<PROFILE>\AppData\Roaming\Signal\update-cache'

# Check if the directory exists
if (Test-Path -Path $appdataRoamingSignalFolder) {
	try {
		# Check if the directory has any items
		$items = Get-ChildItem -Path $appdataRoamingSignalFolder -Force
		# Guard clause that activates and exits if the directory is empty
		if (-not $items) {
			Write-Warning "The directory '$appdataRoamingSignalFolder' exists but is empty."
			return
		}
		# Output what will be deleted
		Write-Host "Deleting the following items:"
		$items | ForEach-Object { Write-Host " - $($_.FullName)" }
		# Delete all files and folders within the directory
		$items | Remove-Item -Recurse -Force
		Write-Host "Successfully deleted the contents of '$appdataRoamingSignalFolder'."
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$appdataRoamingSignalFolder': $($_.Exception.Message)."
	}
}
else {
	Write-Warning "The directory '$appdataRoamingSignalFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.