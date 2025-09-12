# This script removes Microsoft Start Experiences App and must be run as Administrator, which requires the following:
# 1. Create a shortcut to the .ps1 file, set the "Target" field to C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& C:\Users\<PROFILE>\Scripts\remove_start_experiences.ps1"
# 2. Enable "Run as administrator" in the Shortcut tab -> Advanced)

# Remove Start Experiences
Get-AppxPackage -Name Microsoft.StartExperiencesApp | Remove-AppxPackage -ErrorAction SilentlyContinue

Write-Host "Successfully uninstalled 'Microsoft Start Experiences App'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.