# This script deletes the contents of a specific folder

# Specify the directory to process (the name of this directory may be different on your computer)
$appdataLocalPackagesWingetlogFolder = "C:\Users\<PROFILE>\AppData\Local\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"

# Delete all items in the specified directory
Get-ChildItem -Path $appdataLocalPackagesWingetlogFolder -Recurse | Remove-Item -Force -Recurse

Write-Host "Successfully deleted the contents of '$appdataLocalPackagesWingetlogFolder'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.