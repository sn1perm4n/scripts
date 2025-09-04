# This script deletes all but the most recent folder that starts with the letter "A" in a specific directory

# Specify the directory to process
$appleInstallerCacheFolder = "C:\ProgramData\Apple\Installer Cache"

# Get all folders in the directory that start with "A"
$foldersStartingWithA = Get-ChildItem -Path $appleInstallerCacheFolder -Directory | Where-Object { $_.Name -like "A*" }

# Find the most recently modified folder that starts with "A"
$latestAFolder = $foldersStartingWithA | Sort-Object LastWriteTime -Descending | Select-Object -First 1

# Output which folder is being kept
Write-Host "Keeping folder: $($latestAFolder.Name)"

# Get all files/folders in the directory
$allFolders = Get-ChildItem -Path $appleInstallerCacheFolder

# Delete all files/folders except the latest folder that starts with "A"
foreach ($folder in $allFolders) {
    if ($latestAFolder -and $folder.FullName -ne $latestAFolder.FullName) {
        Write-Host "Deleting folder: $($folder.FullName)"
        Remove-Item -Path $folder.FullName -Recurse -Force
    }
}

Write-Host "Successfully deleted all but the latest folder that starts with the character 'A' in '$appleInstallerCacheFolder'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.