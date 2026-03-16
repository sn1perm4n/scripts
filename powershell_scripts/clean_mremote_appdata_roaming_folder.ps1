# This script deletes all *.backup files aside from the most recent one in a specific folder

# Specify the directory to process
$appdataRoamingMremoteng = 'C:\Users\<PROFILE>\AppData\Roaming\mRemoteNG'

# Check if the directory exists
if (Test-Path -Path $appdataRoamingMremoteng) {
	try {
		# Get all .backup files, sorted by LastWriteTime (newest first)
		$backupFiles = Get-ChildItem -Path $appdataRoamingMremoteng -Filter "*.backup" -File | Sort-Object LastWriteTime -Descending
		# Guard clause that activates and exits if 0 or 1 .backup file is found
		if ($backupFiles.Count -le 1) {
			Write-Warning "Found $($backupFiles.Count) .backup file(s). Nothing to delete."
			return
		}
		# Keep the most recent .backup file
		$keepFile = $backupFiles[0]
		Write-Host "Keeping file: $($keepFile.FullName)"
		# Delete the remaining .backup files
		foreach ($backupFile in $backupFiles | Select-Object -Skip 1) {
			Write-Host "Deleting: $($backupFile.FullName)"
			Remove-Item -Path $backupFile.FullName -Force
		}
		Write-Host "Successfully deleted all .backup files with the exception of the newest from '$appdataRoamingMremoteng'."
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$appdataRoamingMremoteng': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$appdataRoamingMremoteng' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.