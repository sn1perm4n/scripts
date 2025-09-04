# This script deletes all .backup files aside from the most recent one in a specific folder

# Specify the directory to process
$appdataRoamingMremotengFolder = "C:\Users\<PROFILE>\AppData\Roaming\mRemoteNG"

# Get all *.backup files in the specified directory (and subfolders if -Recurse is added)
# -Filter "*.backup" ensures only files with the .backup extension are selected
# -File ensures only files are processed, not directories
$backupFile = Get-ChildItem -Path $appdataRoamingMremotengFolder -Filter "*.backup" -File | Select-Object -Skip 1

# Iterate through each identified backup file and delete it
foreach ($backupFile in $backupFile) {
    Write-Host "Deleting: $($BackupFile.FullName)"
    Remove-Item -Path $BackupFile.FullName -Force
}

Write-Host "All .backup files successfully deleted from '$appdataRoamingMremotengFolder' with the exception of the most recent."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.