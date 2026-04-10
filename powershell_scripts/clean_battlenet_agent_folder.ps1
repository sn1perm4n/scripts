# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all but the most recent folder that starts with the character "A" in a specific directory:
# C:\ProgramData\Battle.net\Agent

#Requires -RunAsAdministrator

# Get the script name for summary output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Specify the directory to process
$battlenetAgentFolder = 'C:\ProgramData\Battle.net\Agent'

Write-Host "`nChecking '$battlenetAgentFolder'..." -ForegroundColor Cyan

# Check if the directory exists
if (Test-Path -Path $battlenetAgentFolder) {
	try {
		# Get all folders in the directory that start with "A"
		$foldersStartingWithA = Get-ChildItem -Path $battlenetAgentFolder -Directory | Where-Object { $_.Name -clike 'A*' }

		# Guard clause that activates and exits if no "A" folders exist
		if (-not $foldersStartingWithA) {
			Write-Host ""
			Write-Warning "No folders starting with 'A' found in '$battlenetAgentFolder'."
			exit 0
		}

		# Find the most recently modified folder that starts with "A"
		$latestAFolder = $foldersStartingWithA | Sort-Object LastWriteTime -Descending | Select-Object -First 1
		Write-Host "`nKeeping folder: $($latestAFolder.Name)" -ForegroundColor Green

		$totalBytesFreed = 0
		$deletedCount = 0

		# Delete all "A" folders with the exception of the newest
		foreach ($folder in $foldersStartingWithA) {
			if ($folder.FullName -ne $latestAFolder.FullName) {
				$folderSize = (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
				if (-not $folderSize) { $folderSize = 0 }
				Write-Host "Deleting folder: $($folder.FullName)" -ForegroundColor Yellow
				Remove-Item -Path $folder.FullName -Recurse -Force
				$totalBytesFreed += $folderSize
				$deletedCount++
			}
		}

		if ($deletedCount -eq 0) {
			Write-Host "`nOnly one folder starting with 'A' exists. Nothing deleted." -ForegroundColor Yellow
			exit 0
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
		Write-Error "An error occurred while trying to delete items in '$battlenetAgentFolder': $($_.Exception.Message)"
		exit 1
	}
}
else {
	Write-Host ""
	Write-Warning "The directory '$battlenetAgentFolder' does not exist."
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.