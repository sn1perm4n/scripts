# This script deletes all empty folders from a specific directory

function Remove-EmptyFolders {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
	
	# Check if the specified folder exists
	if (-not (Test-Path -Path $Path -PathType Container)) {
        Write-Host "The specified path '$Path' does not exist or is not a directory."
        return
    }
	
    # Get all directories, sorted by depth (deepest first)
    # This ensures that empty subfolders are deleted before their parent folders
    $folders = Get-ChildItem -LiteralPath $Path -Directory -Recurse | 
               Sort-Object FullName -Descending

    foreach ($folder in $folders) {
        # Check if the folder is empty (contains no files or subfolders)
        if (-not (Get-ChildItem -LiteralPath $folder.FullName -Recurse -Force | Select-Object -First 1)) {
            Write-Host "Deleting empty folder: $($folder.FullName)"
            Remove-Item -LiteralPath $folder.FullName -Recurse -Force -Confirm:$false
        } 
    }
	Write-Host "Successfully deleted all empty folders from '$downloadsSoulseekCompleteFolder'."
}

# Specify the directory to process
$downloadsSoulseekCompleteFolder = "D:\Downloads\soulseek-downloads\complete"

# Call the function to remove empty folders
Remove-EmptyFolders -Path $downloadsSoulseekCompleteFolder

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.