# This script deletes all but the most recent file and folder in a specific folder

# Specify the directory to process
$appdataLocalMremotengFolder = "C:\Users\<PROFILE>\AppData\Local\mRemoteNG\mRemoteNG.exe_Url_pjpxdehxpaaorqg2thmuhl11a34i3ave"

# Get all files and folders within the directory
$items = Get-ChildItem -Path $appdataLocalMremotengFolder

# Sort the items by LastWriteTime in descending order
$sortedItems = $items | Sort-Object LastWriteTime -Descending

# Remove all but the most recent item from the list
$itemsToDelete = $sortedItems | Select-Object -Skip 1

# Delete all items except the two most recent
if ($itemsToDelete) {
    Write-Host "Deleting the following items:"
    foreach ($itemToDelete in $itemsToDelete) {
        Write-Host $itemToDelete.FullName
        Remove-Item -Force $itemToDelete.FullName -Recurse
    }
} else {
    Write-Host "No items to delete. The folder is empty or contains only two items."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.