# This script deletes all but the most recent folder that starts with the character 'A' in a specific directory

# Specify the directory to process
$battlenetAgentFolder = "C:\ProgramData\Battle.net\Agent"

# Get all subfolders starting with the character 'A'
$folders = Get-ChildItem -Path $battlenetAgentFolder -Directory | Where-Object { $_.Name -like "A*" }

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
	Write-Host "No folders to delete. The folder doesn't contain any folders that start with the character 'A' or only contains one such folder."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.