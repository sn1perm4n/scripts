# This script deletes all but the most recent file and folder in a specific folder:
# C:\ProgramData\Patch My PC\Patch My PC Home Updater\updates

#Requires -RunAsAdministrator

# Specify the directory to process
$programdataPatchmypcFolder = 'C:\ProgramData\Patch My PC\Patch My PC Home Updater\updates'

# Guard clauses
if (-not (Test-Path $programdataPatchmypcFolder)) {
	Write-Host "`nThe directory '$programdataPatchmypcFolder' does not exist." -ForegroundColor Yellow
	exit
}

if (-not (Get-ChildItem -Path $programdataPatchmypcFolder -Force)) {
	Write-Host "`nThe directory '$programdataPatchmypcFolder' is empty." -ForegroundColor Yellow
	exit
}

try {
	# Initialize counters to track deletions
	$deletedFilesCount = 0
	$deletedFoldersCount = 0

	# Keep only the most recent file
	$files = Get-ChildItem -Path $programdataPatchmypcFolder -File
	if ($files.Count -gt 0) {
		$latestFile = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
		Write-Host "`nKeeping file: $($latestFile.FullName)" -ForegroundColor Cyan

		if ($files.Count -gt 1) {
			$files | Sort-Object LastWriteTime -Descending | Select-Object -Skip 1 |
				ForEach-Object {
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
		Write-Host "`nKeeping folder: $($latestFolder.FullName)" -ForegroundColor Cyan

		if ($folders.Count -gt 1) {
			$folders | Sort-Object LastWriteTime -Descending | Select-Object -Skip 1 |
				ForEach-Object {
					Write-Host "Deleting folder: $($_.FullName)" -ForegroundColor Yellow
					Remove-Item $_.FullName -Recurse -Force
					$deletedFoldersCount++
				}
		}
	}

	# Report final status
	if ($deletedFilesCount -gt 0 -or $deletedFoldersCount -gt 0) {
		Write-Host "`nSuccessfully deleted all but the most recent file and folder in '$programdataPatchmypcFolder'." -ForegroundColor Green
	}
	else {
		Write-Host "`nNo deletions were necessary." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	Write-Error "An error occurred while trying to delete items in '$programdataPatchmypcFolder': $($_.Exception.Message)"
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.
