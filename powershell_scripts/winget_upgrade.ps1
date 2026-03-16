# This script updates the winget source database and then runs the upgrade command so potential updates can be seen (must be run as Administrator)
# Individual packages can be upgraded via their ID, i.e.: "winget upgrade Microsoft.VCRedist.2013.x86"
# If you want to upgrade everything, you can run "winget upgrade --all"
# Available commands: https://learn.microsoft.com/en-us/windows/package-manager/winget/upgrade
# winget pin add --id <APP_ID> - Disables version checking for said app (useful if you need to avoid upgrading specific applications)
# winget pin remove --id <APP_ID> - Removes a pinned app from winget
# winget pin list - Shows the current pinned app list

# Update source database
winget source update

# Show programs that need updating
winget upgrade

exit

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.