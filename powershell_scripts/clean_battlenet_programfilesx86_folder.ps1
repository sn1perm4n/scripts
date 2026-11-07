# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all but the highest-numbered versioned Battle.net folder (i.e. Battle.net.17986) in a specific directory:
# C:\Program Files (x86)\Battle.net

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Specify the directory to process
$parentFolder = 'C:\Program Files (x86)\Battle.net'

Write-Host "`nChecking '$parentFolder'..." -ForegroundColor Cyan

# Check if the directory exists
if (Test-Path -Path $parentFolder) {
	try {
		# Get all versioned Battle.net subfolders (i.e. Battle.net.17986), each paired with the build number at the end of its name
		$folders = Get-ChildItem -Path $parentFolder -Directory | Where-Object { $_.Name -match '^Battle\.net\.\d+$' } | ForEach-Object {
			[PSCustomObject]@{
				Folder = $_
				Build = [long]($_.Name -replace '^Battle\.net\.', '')
			}
		}

		if (-not $folders) {
			Write-Host ""
			Write-Warning "No versioned Battle.net folders found in '$parentFolder'."
			exit 0
		}

		# Sort folders by build number descending (highest first), since LastWriteTime is unreliable here - a folder's LastWriteTime changes whenever its contents are added or removed, so an old folder emptied during an update can look newer than the real one
		$sortedFolders = $folders | Sort-Object Build -Descending

		# Keep the folder with the highest build number
		$keep = ($sortedFolders | Select-Object -First 1).Folder

		# Never delete anything if the folder being kept is empty (i.e. an update is in progress or has failed), since an older folder may still be the only complete copy
		$keepHasFiles = Get-ChildItem -Path $keep.FullName -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
		if (-not $keepHasFiles) {
			Write-Host ""
			Write-Warning "The highest-numbered folder '$($keep.FullName)' is empty, so nothing was deleted."
			exit 1
		}

		Write-Host "`nKeeping folder: $($keep.FullName)" -ForegroundColor Green

		# Skip the kept folder and delete the rest
		$foldersToDelete = $sortedFolders | Select-Object -Skip 1 | ForEach-Object { $_.Folder }

		if (-not $foldersToDelete) {
			Write-Host "`n$ScriptName`: [$env:COMPUTERNAME] Only one versioned Battle.net folder exists, nothing to delete." -ForegroundColor Yellow
			exit 0
		}

		$totalBytesFreed = 0
		$deletedCount = 0

		foreach ($folder in $foldersToDelete) {
			$folderSize = (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
			if (-not $folderSize) { $folderSize = 0 }
			Write-Host "Deleting folder: $($folder.FullName)" -ForegroundColor Yellow
			Remove-Item -Path $folder.FullName -Recurse -Force
			$totalBytesFreed += $folderSize
			$deletedCount++
		}

		# Summary
		$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
		$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
		$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" }
else { "$totalFreedMB MB" }
		$folderWord = if ($deletedCount -eq 1) { "folder" }
else { "folders" }
		Write-Host "`n$ScriptName`: [$env:COMPUTERNAME] $deletedCount $folderWord deleted, $freedDisplay freed." -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Error "An error occurred while trying to delete items in '$parentFolder': $($_.Exception.Message)"
		exit 1
	}
}
else {
	Write-Host ""
	Write-Warning "The directory '$parentFolder' does not exist."
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.