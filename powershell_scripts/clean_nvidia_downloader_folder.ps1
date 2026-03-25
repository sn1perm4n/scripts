# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes the contents of a specific folder:
# C:\ProgramData\NVIDIA Corporation\Downloader

#Requires -RunAsAdministrator

# Specify the directory to process
$programdataNvidiacorporationDownloader = 'C:\ProgramData\NVIDIA Corporation\Downloader'

# Check if the directory exists
if (Test-Path -Path $programdataNvidiacorporationDownloader) {
	try {
		# Check if the directory has any items
		$items = Get-ChildItem -Path $programdataNvidiacorporationDownloader -Force

		# Guard clause that activates and exits if the directory is empty
		if (-not $items) {
			Write-Warning "The directory '$programdataNvidiacorporationDownloader' exists but is empty."
			return
		}

		# Output what will be deleted
		Write-Host "Deleting the following items from '$programdataNvidiacorporationDownloader':"
		$items | ForEach-Object { Write-Host " - $($_.FullName)" }

		# Delete all files and folders within the directory
		$items | Remove-Item -Recurse -Force

		Write-Host "Successfully deleted the contents of '$programdataNvidiacorporationDownloader'."
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$programdataNvidiacorporationDownloader': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$programdataNvidiacorporationDownloader' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.