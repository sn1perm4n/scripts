# This script deletes the contents of a specific folder

# Specify the directory to process
$programdataSamsungBackupFolder = "C:\ProgramData\Samsung\Backup"

# Delete all items in the specified directory
Get-ChildItem -Path $programdataSamsungBackupFolder -Recurse | Remove-Item -Force -Recurse

Write-Host "Successfully deleted the contents of '$programdataSamsungBackupFolder'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.