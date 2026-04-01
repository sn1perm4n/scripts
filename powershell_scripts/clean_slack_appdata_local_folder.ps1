# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script searches a specific folder for subfolders that start with the characters "app-" and keeps the one with the highest number:
# $env:LOCALAPPDATA\slack (resolves to C:\Users\<username>\AppData\Local\slack)

# Specify the directory to process
$appdataLocalSlackFolder = "$env:LOCALAPPDATA\slack"

# Get the script name for summary output
$ScriptName = Split-Path $PSCommandPath -Leaf

Write-Host "`nChecking '$appdataLocalSlackFolder'..." -ForegroundColor Cyan

# Check if the directory exists
if (Test-Path -Path $appdataLocalSlackFolder) {
	try {
		# Get all directories starting with "app-"
		$appDirs = Get-ChildItem -Path $appdataLocalSlackFolder -Directory | Where-Object { $_.Name -like 'app-*' }

		# Guard clause that activates and exits if there's only 0 or 1 "app-" folder
		if ($appDirs.Count -le 1) {
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
			Write-Warning "No folders starting with 'app-' found in '$appdataLocalSlackFolder'."
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
		Write-Error "An error occurred while trying to delete items in '$appdataLocalSlackFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$appdataLocalSlackFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.