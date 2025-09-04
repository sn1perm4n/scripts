# This script queries all Installed Programs and outputs to a .csv file

Get-WmiObject Win32_Product |
Sort-Object Name |
Select Name,Vendor,Version |
Export-Csv -Path C:\Users\<PROFILE>\Desktop\Installed_Programs_List.csv -NoTypeInformation

Write-Host "Successfully queried all Installed Programs and wrote them to 'Installed_Programs_List.csv'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.