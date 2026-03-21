# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes the contents of a specific folder:
# $env:APPDATA\Signal\update-cache (resolves to C:\Users\<username>\AppData\Roaming\Signal\update-cache)

# Specify the directory to process
$appdataRoamingSignalFolder = "C:\Users\$env:APPDATA\Signal\update-cache"

Write-Host "`nChecking '$appdataRoamingSignalFolder'..." -ForegroundColor Cyan

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
		Write-Host "`nDeleting the following items:"
		$items | ForEach-Object { Write-Host " - $($_.FullName)" }
		# Delete all files and folders within the directory
		$items | Remove-Item -Recurse -Force
		Write-Host "`nSuccessfully deleted the contents of '$appdataRoamingSignalFolder'." -ForegroundColor Green
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$appdataRoamingSignalFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$appdataRoamingSignalFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.