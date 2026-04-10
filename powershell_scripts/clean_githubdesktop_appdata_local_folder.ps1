# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script searches a specific folder for subfolders that start with the characters "app-" and keeps the one with the highest number:
# $env:LOCALAPPDATA\GitHubDesktop (resolves to C:\Users\<username>\AppData\Local\GitHubDesktop)

# Specify the target directory
$appdataLocalGitHubDesktopFolder = "$env:LOCALAPPDATA\GitHubDesktop"

# Get the script name for summary output
$ScriptName = Split-Path $PSCommandPath -Leaf

Write-Host "`nChecking '$appdataLocalGitHubDesktopFolder'..." -ForegroundColor Cyan

# Check if the directory exists
if (Test-Path -Path $appdataLocalGitHubDesktopFolder) {
	try {
		# Get all directories starting with "app-"
		$appDirs = Get-ChildItem -Path $appdataLocalGitHubDesktopFolder -Directory | Where-Object { $_.Name -like 'app-*' }

		# Guard clause that activates and exits if there's only 0 or 1 "app-" folder
		if ($appDirs.Count -le 1) {
			Write-Host ""
			Write-Warning "Only $($appDirs.Count) 'app-' folder found, nothing to delete."
			exit 0
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
			Write-Host ""
			Write-Warning "No folders starting with 'app-' found in '$appdataLocalGitHubDesktopFolder'."
			exit 0
		}

		# Keep the highest "app-" version
		$keep = $appNumbers | Select-Object -First 1
		Write-Host "`nKeeping folder: $($keep.Name)" -ForegroundColor Green

		# Calculate and delete all other "app-" versions
		$totalBytesFreed = 0
		$deletedCount = 0
		$appNumbers | Where-Object { $_.Path -ne $keep.Path } | ForEach-Object {
			$folderSize = (Get-ChildItem -Path $_.Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
			if (-not $folderSize) { $folderSize = 0 }
			Write-Host "Deleting folder: $($_.Path)" -ForegroundColor Yellow
			Remove-Item -Path $_.Path -Recurse -Force
			$totalBytesFreed += $folderSize
			$deletedCount++
		}

		# Summary
		$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
		$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
		$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" } else { "$totalFreedMB MB" }
		$folderWord = if ($deletedCount -eq 1) { "folder" } else { "folders" }
		Write-Host "`n$ScriptName`: $deletedCount $folderWord deleted, $freedDisplay freed." -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Error "An error occurred while trying to delete items in '$appdataLocalGitHubDesktopFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Host ""
	Write-Warning "The directory '$appdataLocalGitHubDesktopFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.