# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all but the most recent folder in a specific folder:
# $env:LOCALAPPDATA\mRemoteNG\mRemoteNG.exe_Url_pjpxdehxpaaorqg2thmuhl11a34i3ave (resolves to C:\Users\<username>\AppData\Local\mRemoteNG\mRemoteNG.exe_Url_pjpxdehxpaaorqg2thmuhl11a34i3ave)

# Specify the directory to process (the name of this directory may be different on your computer)
$appdataLocalMremotengFolder = "$env:LOCALAPPDATA\mRemoteNG\mRemoteNG.exe_Url_pjpxdehxpaaorqg2thmuhl11a34i3ave"

# Get the script name for summary output
$ScriptName = Split-Path $PSCommandPath -Leaf

Write-Host "`nChecking '$appdataLocalMremotengFolder'..." -ForegroundColor Cyan

# Check if the directory exists
if (Test-Path -Path $appdataLocalMremotengFolder) {
	try {
		# Get all folders within the directory
		$items = Get-ChildItem -Path $appdataLocalMremotengFolder -Directory

		# Guard clause that activates and exits if there's only 0 or 1 folder
		if ($items.Count -le 1) {
			Write-Host ""
			Write-Warning "The directory '$appdataLocalMremotengFolder' contains $($items.Count) folder(s), nothing to delete."
			exit 0
		}

		# Sort the items by LastWriteTime in descending order
		$sortedItems = $items | Sort-Object LastWriteTime -Descending
		$latestItem = $sortedItems | Select-Object -First 1
		$itemsToDelete = $sortedItems | Select-Object -Skip 1

		Write-Host "`nKeeping folder: $($latestItem.FullName)" -ForegroundColor Green

		$totalBytesFreed = 0
		$deletedCount = 0

		foreach ($itemToDelete in $itemsToDelete) {
			$folderSize = (Get-ChildItem -Path $itemToDelete.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
			if (-not $folderSize) { $folderSize = 0 }
			Write-Host "Deleting folder: $($itemToDelete.FullName)" -ForegroundColor Yellow
			Remove-Item -Path $itemToDelete.FullName -Recurse -Force
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
		Write-Error "An error occurred while trying to delete items in '$appdataLocalMremotengFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Host ""
	Write-Warning "The directory '$appdataLocalMremotengFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.