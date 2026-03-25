# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script keeps only the latest folder that starts with the characters "Apple Software Update*" in a specific folder (all other folders are deleted):
# C:\ProgramData\Apple\Installer Cache

#Requires -RunAsAdministrator

# Specify the directory to process
$appleInstallerCacheFolder = 'C:\ProgramData\Apple\Installer Cache'

# Check that the directory exists
if (Test-Path -Path $appleInstallerCacheFolder) {
	try {
		# Find the newest "Apple Software Update*" folder
		$latestASU = Get-ChildItem -Path $appleInstallerCacheFolder -Directory |
					Where-Object { $_.Name -like 'Apple Software Update*' } |
					Sort-Object LastWriteTime -Descending |
					Select-Object -First 1

		if (-not $latestASU) {
			Write-Warning "No folders starting with 'Apple Software Update' were found in '$appleInstallerCacheFolder'. Nothing deleted."
			return
		}

		Write-Host "Keeping the newest Apple Software Update folder: $($latestASU.FullName)" -ForegroundColor Green

		# Delete all other folders (including non-ASU folders)
		Get-ChildItem -Path $appleInstallerCacheFolder -Directory |
		Where-Object { $_.FullName -ne $latestASU.FullName } |
		ForEach-Object {
			Write-Host "Deleting folder: $($_.FullName)" -ForegroundColor Yellow
			Remove-Item -Path $_.FullName -Recurse -Force
		}

		Write-Host "Successfully deleted all folders except '$($latestASU.Name)'." -ForegroundColor Green
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$appleInstallerCacheFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$appleInstallerCacheFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.