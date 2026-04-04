# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all but the most recent folder that starts with the character 'B' in a specific directory:
# C:\Program Files (x86)\Battle.net

#Requires -RunAsAdministrator

# Get the script name for summary output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Specify the directory to process
$parentFolder = 'C:\Program Files (x86)\Battle.net'

Write-Host "`nChecking '$parentFolder'..." -ForegroundColor Cyan

# Check if the directory exists
if (Test-Path -Path $parentFolder) {
	try {
		# Get all subfolders starting with the character 'B'
		$folders = Get-ChildItem -Path $parentFolder -Directory | Where-Object { $_.Name -like 'B*' }

		if (-not $folders) {
			Write-Warning "No folders starting with 'B' found in '$parentFolder'."
			exit 0
		}

		# Sort folders by LastWriteTime descending (most recent first)
		$sortedFolders = $folders | Sort-Object LastWriteTime -Descending

		# Keep the most recent folder
		$keep = $sortedFolders | Select-Object -First 1
		Write-Host "`nKeeping folder: $($keep.FullName)" -ForegroundColor Green

		# Skip the most recent folder and delete the rest
		$foldersToDelete = $sortedFolders | Select-Object -Skip 1

		if (-not $foldersToDelete) {
			Write-Host "`nOnly one 'B' folder exists, nothing to delete." -ForegroundColor Yellow
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
		$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" } else { "$totalFreedMB MB" }
		$folderWord = if ($deletedCount -eq 1) { "folder" } else { "folders" }
		Write-Host "`n$ScriptName`: $deletedCount $folderWord deleted, $freedDisplay freed." -ForegroundColor Green
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$parentFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$parentFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.