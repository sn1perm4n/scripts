# This script queries Installed Programs and outputs to a .csv file on the Desktop

Get-WmiObject Win32_Product |
Sort-Object Name |
Select Name,Vendor,Version |
Export-Csv -Path C:\Users\<PROFILE>\Desktop\Installed_Programs_List.csv -NoTypeInformation

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.