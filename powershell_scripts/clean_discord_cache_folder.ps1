# This script searches a specific directory for folders that start with the characters "app-" and keeps the one with the highest number

# Specify the target directory
$appdataLocalDiscordFolder = "C:\Users\<PROFILE>\AppData\Local\Discord"

# Get all directories starting with "app-"
$appDirs = Get-ChildItem -Path $appdataLocalDiscordFolder -Directory | Where-Object { $_.Name -like 'app-*' }

# Extract numeric part and sort
$appNumbers = $appDirs | ForEach-Object {
    $name = $_.Name
    $path = $_.FullName
    if ($name -match '^app-(\d+(?:\.\d+)*)$') {
        [PSCustomObject]@{
            Name = $name
            Path = $path
            Version = [version]$matches[1]
        }
    }
} | Sort-Object Version -Descending

# Keep the highest version
$keep = $appNumbers | Select-Object -First 1

# Delete all other versions
$appNumbers | Where-Object { $_.Path -ne $keep.Path } | ForEach-Object {
    Write-Output "Deleting: $($_.Path)"
    Remove-Item -Path $_.Path -Recurse -Force
}

Write-Host "Deleted all app-a folders with the exception of $($keep.Path)."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.