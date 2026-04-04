# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all but the most recent file and folder in a specific folder:
# C:\ProgramData\Patch My PC\Patch My PC Home Updater\updates

#Requires -RunAsAdministrator

# Specify the directory to process
$programdataPatchmypcFolder = 'C:\ProgramData\Patch My PC\Patch My PC Home Updater\updates'

# Get the script name for summary output
$ScriptName = Split-Path $PSCommandPath -Leaf

Write-Host "`nChecking '$programdataPatchmypcFolder'..." -ForegroundColor Cyan

# Guard clauses
if (-not (Test-Path $programdataPatchmypcFolder)) {
	Write-Warning "The directory '$programdataPatchmypcFolder' does not exist."
	exit 0
}

if (-not (Get-ChildItem -Path $programdataPatchmypcFolder -Force)) {
	Write-Warning "The directory '$programdataPatchmypcFolder' is empty."
	exit 0
}

try {
	$totalBytesFreed = 0
	$deletedFilesCount = 0
	$deletedFoldersCount = 0

	# Keep only the most recent file
	$files = Get-ChildItem -Path $programdataPatchmypcFolder -File
	if ($files.Count -gt 0) {
		$latestFile = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
		Write-Host "`nKeeping file: $($latestFile.FullName)" -ForegroundColor Green

		if ($files.Count -gt 1) {
			$files | Sort-Object LastWriteTime -Descending | Select-Object -Skip 1 | ForEach-Object {
				$totalBytesFreed += $_.Length
				Write-Host "Deleting file: $($_.FullName)" -ForegroundColor Yellow
				Remove-Item $_.FullName -Force
				$deletedFilesCount++
			}
		}
	}

	# Keep only the most recent folder
	$folders = Get-ChildItem -Path $programdataPatchmypcFolder -Directory
	if ($folders.Count -gt 0) {
		$latestFolder = $folders | Sort-Object LastWriteTime -Descending | Select-Object -First 1
		Write-Host "`nKeeping folder: $($latestFolder.FullName)" -ForegroundColor Green

		if ($folders.Count -gt 1) {
			$folders | Sort-Object LastWriteTime -Descending | Select-Object -Skip 1 | ForEach-Object {
				$folderSize = (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
				if (-not $folderSize) { $folderSize = 0 }
				$totalBytesFreed += $folderSize
				Write-Host "Deleting folder: $($_.FullName)" -ForegroundColor Yellow
				Remove-Item $_.FullName -Recurse -Force
				$deletedFoldersCount++
			}
		}
	}

	# Summary
	$totalDeleted = $deletedFilesCount + $deletedFoldersCount
	if ($totalDeleted -gt 0) {
		$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
		$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
		$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" } else { "$totalFreedMB MB" }
		Write-Host "`n$ScriptName`: $deletedFilesCount file(s) and $deletedFoldersCount folder(s) deleted, $freedDisplay freed." -ForegroundColor Green
	}
	else {
		Write-Host "`nNo deletions were necessary." -ForegroundColor Yellow
	}
}
catch {
	Write-Host ""
	Write-Error "An error occurred while trying to delete items in '$programdataPatchmypcFolder': $($_.Exception.Message)"
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.
