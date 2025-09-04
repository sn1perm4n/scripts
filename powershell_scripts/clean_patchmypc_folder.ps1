# This script deletes all but the most recent file and folder in a specific directory

# Specify the directory to process
$programdataPatchmypcFolder = "C:\ProgramData\Patch My PC\Patch My PC Home Updater\updates"

# Get all files and subdirectories within the directory (can add -Recurse to scan all folders)
$items = Get-ChildItem -Path $programdataPatchmypcFolder

# Sort the items by LastWriteTime in descending order
$sortedItems = $items | Sort-Object LastWriteTime -Descending

# Remove the two most recent items from the list
$itemsToDelete = $sortedItems | Select-Object -Skip 2

# Delete all items except the two most recent
if ($itemsToDelete) {
    foreach ($itemToDelete in $itemsToDelete) {
        Write-Host "Deleting the following folders: $itemToDelete"
        Remove-Item $itemToDelete.FullName -Recurse -Force
    }
} else {
    Write-Host "No items to delete. The folder is empty or contains only two items."
}

Write-Host "Successfully deleted all but the most recent file and folder in '$programdataPatchmypcFolder'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.