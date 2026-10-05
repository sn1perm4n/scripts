# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all folders and all files except the *.aiu file in:
# C:\ProgramData\Patch My PC\Patch My PC Home Updater\updates

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Specify the directory to process
$programdataPatchmypcFolder = 'C:\ProgramData\Patch My PC\Patch My PC Home Updater\updates'

Write-Host "`nChecking '$programdataPatchmypcFolder'..." -ForegroundColor Cyan

# Guard clauses
if (-not (Test-Path $programdataPatchmypcFolder)) {
	Write-Host ""
	Write-Warning "The directory '$programdataPatchmypcFolder' does not exist."
	exit 0
}

if (-not (Get-ChildItem -Path $programdataPatchmypcFolder -Force)) {
	Write-Host ""
	Write-Warning "The directory '$programdataPatchmypcFolder' is empty."
	exit 0
}

try {
	$totalBytesFreed = 0
	$deletedFilesCount = 0
	$deletedFoldersCount = 0

	# Keep only the *.aiu file (the update-check metadata the program actually needs); everything else here is disposable installer/artifact content
	$files = Get-ChildItem -Path $programdataPatchmypcFolder -File
	if ($files.Count -gt 0) {
		$aiuFiles = @($files | Where-Object { $_.Extension -eq '.aiu' })
		$latestAiuFile = $null

		if ($aiuFiles.Count -eq 0) {
			Write-Host ""
			Write-Warning "No .aiu file found in '$programdataPatchmypcFolder' - nothing will be kept."
		}
		else {
			$latestAiuFile = $aiuFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
			Write-Host "`nKeeping file: $($latestAiuFile.FullName)" -ForegroundColor Green
		}

		$files | Where-Object { -not $latestAiuFile -or $_.FullName -ne $latestAiuFile.FullName } | ForEach-Object {
			$totalBytesFreed += $_.Length
			Write-Host "Deleting file: $($_.FullName)" -ForegroundColor Yellow
			Remove-Item $_.FullName -Force
			$deletedFilesCount++
		}
	}

	# Delete all folders - the most recent one historically only ever contained a redownloadable installer (i.e. PatchMyPC-HomeUpdater.msi), with no reason to keep it locally
	$folders = Get-ChildItem -Path $programdataPatchmypcFolder -Directory
	foreach ($folder in $folders) {
		$folderSize = (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
		if (-not $folderSize) { $folderSize = 0 }
		$totalBytesFreed += $folderSize
		Write-Host "Deleting folder: $($folder.FullName)" -ForegroundColor Yellow
		Remove-Item $folder.FullName -Recurse -Force
		$deletedFoldersCount++
	}

	# Summary
	$totalDeleted = $deletedFilesCount + $deletedFoldersCount
	if ($totalDeleted -gt 0) {
		$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
		$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
		$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" }
else { "$totalFreedMB MB" }
		$fileWord = if ($deletedFilesCount -eq 1) { "file" }
else { "files" }
		$folderWord = if ($deletedFoldersCount -eq 1) { "folder" }
else { "folders" }
		Write-Host "`n$ScriptName`: $deletedFilesCount $fileWord and $deletedFoldersCount $folderWord deleted, $freedDisplay freed." -ForegroundColor Green
	}
	else {
		Write-Host "`nNo deletions were necessary." -ForegroundColor Yellow
	}
}
catch {
	Write-Host ""
	Write-Error "An error occurred while trying to delete items in '$programdataPatchmypcFolder': $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.