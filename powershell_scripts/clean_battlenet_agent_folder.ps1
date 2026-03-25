# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all but the most recent folder that starts with the character "A" in a specific directory:
# C:\ProgramData\Battle.net\Agent

#Requires -RunAsAdministrator

# Specify the directory to process
$battlenetAgentFolder = 'C:\ProgramData\Battle.net\Agent'

# Check if the directory exists
if (Test-Path -Path $battlenetAgentFolder) {
	try {
		# Get all folders in the directory that start with "A"
		$foldersStartingWithA = Get-ChildItem -Path $battlenetAgentFolder -Directory | Where-Object { $_.Name -clike "A*" }
		# Guard clause that activates and exits if no "A" folders exist
		if (-not $foldersStartingWithA) {
			Write-Warning "No folders starting with 'A' found in '$battlenetAgentFolder'."
			return
		}
		# Find the most recently modified folder that starts with "A"
		$latestAFolder = $foldersStartingWithA | Sort-Object LastWriteTime -Descending | Select-Object -First 1
		# Output which folder is being kept
		Write-Host "Keeping folder: $($latestAFolder.Name)"
		# Track if any deletions happen
		$deleted = $false
		# Delete all "A" folders with the exception of the newest
		foreach ($folder in $foldersStartingWithA) {
			if ($latestAFolder -and $folder.FullName -ne $latestAFolder.FullName) {
				Write-Host "Deleting folder: $($folder.FullName)"
				Remove-Item -Path $folder.FullName -Recurse -Force
				$deleted = $true
			}
		}
		if ($deleted) {
			Write-Host "Successfully deleted all 'A' folders with the exception of the newest in '$battlenetAgentFolder'."
		}
		else {
			Write-Host "Only one folder starting with 'A' exists. Nothing deleted."
		}
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$battlenetAgentFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$battlenetAgentFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.