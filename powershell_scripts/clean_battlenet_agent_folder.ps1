# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all but the highest-numbered versioned Agent folder (i.e. Agent.8223) in a specific directory:
# C:\ProgramData\Battle.net\Agent

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Specify the directory to process
$battlenetAgentFolder = 'C:\ProgramData\Battle.net\Agent'

Write-Host "`nChecking '$battlenetAgentFolder'..." -ForegroundColor Cyan

# Check if the directory exists
if (Test-Path -Path $battlenetAgentFolder) {
	try {
		# Get all versioned Agent folders in the directory (i.e. Agent.8223), each paired with the build number at the end of its name
		$agentFolders = Get-ChildItem -Path $battlenetAgentFolder -Directory | Where-Object { $_.Name -cmatch '^Agent\.\d+$' } | ForEach-Object {
			[PSCustomObject]@{
				Folder = $_
				Build = [long]($_.Name -replace '^Agent\.', '')
			}
		}

		# Guard clause that activates and exits if no versioned Agent folders exist
		if (-not $agentFolders) {
			Write-Host ""
			Write-Warning "No versioned Agent folders found in '$battlenetAgentFolder'."
			exit 0
		}

		# Find the folder with the highest build number, since LastWriteTime is unreliable here - a folder's LastWriteTime changes whenever its contents are added or removed, so an old folder emptied during an update can look newer than the real one
		$latestAgentFolder = ($agentFolders | Sort-Object Build -Descending | Select-Object -First 1).Folder

		# Never delete anything if the folder being kept is empty (i.e. an update is in progress or has failed), since an older folder may still be the only complete copy
		$keepHasFiles = Get-ChildItem -Path $latestAgentFolder.FullName -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
		if (-not $keepHasFiles) {
			Write-Host ""
			Write-Warning "The highest-numbered folder '$($latestAgentFolder.FullName)' is empty, so nothing was deleted."
			exit 1
		}

		Write-Host "`nKeeping folder: $($latestAgentFolder.Name)" -ForegroundColor Green

		$totalBytesFreed = 0
		$deletedCount = 0

		# Delete all versioned Agent folders with the exception of the highest-numbered one
		foreach ($folder in $agentFolders.Folder) {
			if ($folder.FullName -ne $latestAgentFolder.FullName) {
				$folderSize = (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
				if (-not $folderSize) { $folderSize = 0 }
				Write-Host "Deleting folder: $($folder.FullName)" -ForegroundColor Yellow
				Remove-Item -Path $folder.FullName -Recurse -Force
				$totalBytesFreed += $folderSize
				$deletedCount++
			}
		}

		if ($deletedCount -eq 0) {
			Write-Host "`n$ScriptName`: [$env:COMPUTERNAME] Only one versioned Agent folder exists. Nothing deleted." -ForegroundColor Yellow
			exit 0
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