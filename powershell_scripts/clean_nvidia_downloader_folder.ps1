# This script deletes the contents of a specific folder

# Specify the directory to process
$programdataNvidiacorporationDownloader = "C:\ProgramData\NVIDIA Corporation\Downloader"

# Delete all items in the specified directory
Get-ChildItem -Path $programdataNvidiacorporationDownloader -Recurse | Remove-Item -Force -Recurse

Write-Host "Successfully deleted the contents of '$programdataNvidiacorporationDownloader'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.