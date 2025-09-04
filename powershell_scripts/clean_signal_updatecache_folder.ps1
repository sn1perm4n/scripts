# This script deletes the contents of a specific folder

# Specify the directory to process
$appdataRoamingSignalFolder = "C:\Users\<PROFILE>\AppData\Roaming\Signal\update-cache"

# Delete all items in the specified directory
Get-ChildItem -Path $appdataRoamingSignalFolder -Recurse | Remove-Item -Force -Recurse

Write-Host "Successfully deleted the contents of '$appdataRoamingSignalFolder'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.