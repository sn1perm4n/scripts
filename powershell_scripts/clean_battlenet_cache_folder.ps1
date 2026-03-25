# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes the contents of a specific folder:
# C:\ProgramData\Blizzard Entertainment\Battle.net\Cache

#Requires -RunAsAdministrator

# Specify the directory to process
$battlenetCacheFolder = 'C:\ProgramData\Blizzard Entertainment\Battle.net\Cache'

# Check if the directory exists
if (Test-Path -Path $battlenetCacheFolder) {
	try {
		# Check if the directory has any items
		$items = Get-ChildItem -Path $battlenetCacheFolder -Force
		# Guard clause that activates and exits if the directory is empty
		if (-not $items) {
			Write-Warning "The directory '$battlenetCacheFolder' exists but is empty."
			return
		}
		# Output what will be deleted
		Write-Host "Deleting the following items:"
		$items | ForEach-Object { Write-Host " - $($_.FullName)" }
		# Delete all files and folders within the directory
		$items | Remove-Item -Recurse -Force
		Write-Host "Successfully deleted the contents of '$battlenetCacheFolder'."
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$battlenetCacheFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$battlenetCacheFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.