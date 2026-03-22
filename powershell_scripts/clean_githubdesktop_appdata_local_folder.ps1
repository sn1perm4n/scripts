# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script searches a specific directory for folders that start with the characters "app-" and keeps the one with the highest number:
# C:\Users\<PROFILE>\AppData\Local\GitHubDesktop

# Specify the target directory - Change <PROFILE> to to match your system
$appdataLocalGithubdesktopFolder = 'C:\Users\<PROFILE>\AppData\Local\GitHubDesktop'

# Check if the directory exists
if (Test-Path -Path $appdataLocalGithubdesktopFolder) {
	try {
		# Get all directories starting with "app-"
		$appDirs = Get-ChildItem -Path $appdataLocalGithubdesktopFolder -Directory | Where-Object { $_.Name -like 'app-*' }
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
			Write-Warning "No folders starting with 'app-' found in '$appdataLocalGithubdesktopFolder'."
			return
		}
		# Keep the highest "app-" version
		$keep = $appNumbers | Select-Object -First 1
		Write-Host "Keeping folder: $($keep.Name)" -ForegroundColor Green
		# Delete all other "app-" versions
		$appNumbers | Where-Object { $_.Path -ne $keep.Path } | ForEach-Object {
			Write-Output "Deleting folder: $($_.Path)"
			Remove-Item -Path $_.Path -Recurse -Force
		}
		Write-Host "Successfully deleted all 'app-' folders with the exception of the newest in '$appdataLocalGithubdesktopFolder'." -ForegroundColor Green
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$appdataLocalGithubdesktopFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$appdataLocalGithubdesktopFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.