# This script deletes the contents of a specific folder

# Specify the directory to process
$battlenetCacheFolder = "C:\ProgramData\Blizzard Entertainment\Battle.net\Cache"

# Delete all items in the specified directory
Get-ChildItem -Path $battlenetCacheFolder -Recurse | Remove-Item -Force -Recurse

Write-Host "Successfully deleted the contents of '$battlenetCacheFolder'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.