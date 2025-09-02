# This script deletes the contents of a specific folder

# Specify the directory to process
$appleComputerInstallerCacheFolder = "C:\ProgramData\Apple Computer\Installer Cache"

# Get all files and folders within the folder (can add -Recurse to scan all folders)
Get-ChildItem -Path $appleComputerInstallerCacheFolder -Recurse | Remove-Item -Force -Recurse

Write-Host "Successfully deleted the contents of '$appleComputerInstallerCacheFolder'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.