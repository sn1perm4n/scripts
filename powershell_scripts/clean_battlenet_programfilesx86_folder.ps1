# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all but the most recent folder that starts with the character 'B' in a specific directory:
# C:\Program Files (x86)\Battle.net

#Requires -RunAsAdministrator

# Specify the directory to process
$parentFolder = "C:\Program Files (x86)\Battle.net"

# Get all subfolders starting with the character 'B'
$folders = Get-ChildItem -Path $parentFolder -Directory | Where-Object { $_.Name -like "B*" }

# Sort folders by LastWriteTime descending (most recent first)
$sortedFolders = $folders | Sort-Object LastWriteTime -Descending

# Skip the most recent folder and delete the rest
$foldersToDelete = $sortedFolders | Select-Object -Skip 1

if ($foldersToDelete) {
	foreach ($folder in $foldersToDelete) {
		Write-Host "Deleting the following folder(s): $($folder.FullName)"
		Remove-Item -Path $folder.FullName -Recurse -Force
	}
} else {
	Write-Host "No folders to delete. The folder doesn't contain any folders that start with the character 'B' or only contains one such folder."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.