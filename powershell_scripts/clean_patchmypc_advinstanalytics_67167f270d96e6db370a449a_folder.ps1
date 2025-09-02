# This script deletes all but the most recent folder in a specific directory related to Patch My PC Home

# Specify the directory to process
$appdataLocalAdvinstAnalytics = "C:\Users\<PROFILE>\AppData\Local\AdvinstAnalytics\67167f270d96e6db370a449a"

# Get all subdirectories, sort by creation time (newest first), skip the first (most recent), and remove the rest
Get-ChildItem -Path $appdataLocalAdvinstAnalytics -Directory |
    Sort-Object -Property CreationTime -Descending |
    Select-Object -Skip 1 |
    Remove-Item -Recurse -Force

Write-Host "Successfully deleted all but the most recent folder in '$appdataLocalAdvinstAnalytics'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.