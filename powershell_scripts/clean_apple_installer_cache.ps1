# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script keeps only the latest folder that starts with the characters "Apple Software Update*" in a specific folder (all other folders are deleted):
# C:\ProgramData\Apple\Installer Cache

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Specify the directory to process
$appleInstallerCacheFolder = 'C:\ProgramData\Apple\Installer Cache'

Write-Host "`nChecking '$appleInstallerCacheFolder'..." -ForegroundColor Cyan

# Check that the directory exists
if (Test-Path -Path $appleInstallerCacheFolder) {
	try {
		# Find the newest "Apple Software Update*" folder
		$latestASU = Get-ChildItem -Path $appleInstallerCacheFolder -Directory |
			Where-Object { $_.Name -like 'Apple Software Update*' } |
			Sort-Object LastWriteTime -Descending |
			Select-Object -First 1

		if (-not $latestASU) {
			Write-Host ""
			Write-Warning "No folders starting with 'Apple Software Update' were found in '$appleInstallerCacheFolder'. Nothing deleted."
			exit 0
		}

		Write-Host "`nKeeping the newest Apple Software Update folder: $($latestASU.FullName)" -ForegroundColor Green

		# Calculate size of folders to be deleted before deletion
		$totalBytesFreed = 0
		$deletedCount = 0
		$foldersToDelete = Get-ChildItem -Path $appleInstallerCacheFolder -Directory |
			Where-Object { $_.FullName -ne $latestASU.FullName }

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
		Write-Host "`n$ScriptName`: $deletedCount $folderWord deleted, $freedDisplay freed." -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Error "An error occurred while trying to delete items in '$appleInstallerCacheFolder': $($_.Exception.Message)"
		exit 1
	}
}
else {
	Write-Host ""
	Write-Warning "The directory '$appleInstallerCacheFolder' does not exist."
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.