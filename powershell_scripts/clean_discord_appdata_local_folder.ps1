# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script searches a specific folder for subfolders that start with the characters "app-" and keeps the one with the highest number:
# $env:LOCALAPPDATA\Discord (resolves to C:\Users\<username>\AppData\Local\Discord)

# Specify the target directory
$appdataLocalDiscordFolder = '$env:LOCALAPPDATA\Discord'

# Check if the directory exists
if (Test-Path -Path $appdataLocalDiscordFolder) {
	try {
		# Get all directories starting with "app-"
		$appDirs = Get-ChildItem -Path $appdataLocalDiscordFolder -Directory | Where-Object { $_.Name -like 'app-*' }
		# Guard clause that activates and exits if there's only 0 or 1 "app-" folder
		if ($appDirs.Count -le 1) {
			Write-Warning "Only $($appDirs.Count) 'app-' folder found, nothing to delete."
			return
		}
		# Extract numeric part and sort
		$appNumbers = $appDirs | ForEach-Object {
			$name = $_.Name
			$path = $_.FullName
			if ($name -match '^app-(\d+(?:\.\d+)*)$') {
				[PSCustomObject]@{
				Name = $name
				Path = $path
				Version = [version]$matches[1]
				}
			}
		} | Sort-Object Version -Descending
		if (-not $appNumbers) {
			Write-Warning "No folders starting with 'app-' found in '$appdataLocalDiscordFolder'."
			return
		}
		# Keep the highest "app-" version
		$keep = $appNumbers | Select-Object -First 1
		Write-Host "`nKeeping folder: $($keep.Name)`n" -ForegroundColor Green
		# Delete all other "app-" versions
		$appNumbers | Where-Object { $_.Path -ne $keep.Path } | ForEach-Object {
			Write-Host "Deleting folder: $($_.Path)" -ForegroundColor Yellow
			Remove-Item -Path $_.Path -Recurse -Force
		}
		Write-Host "`nSuccessfully deleted all 'app-' folders with the exception of the newest in '$appdataLocalDiscordFolder'." -ForegroundColor Green
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$appdataLocalDiscordFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$appdataLocalDiscordFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.
