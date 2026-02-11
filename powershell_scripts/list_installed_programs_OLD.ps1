# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script queries Installed Programs and outputs to a .csv file on the Desktop. While it does seem to technically work with PowerShell 7.x, I strongly recommend you use my new script instead: list_installed_programs_local.ps1

Get-WmiObject Win32_Product |
Sort-Object Name |
Select Name,Vendor,Version |
Export-Csv -Path C:\Users\reedwaller\Desktop\Installed_Programs_List.csv -NoTypeInformation

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.