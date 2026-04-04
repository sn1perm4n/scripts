# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables various settings on a Intel 2.5Gb Ethernet card that negatively impact performance (especially for gaming). The name of your Ethernet adapter may differ (i.e. on one of my systems it's "Local Area Connection") so confirm first with the following PowerShell command (if you don't do this you'll see a bunch of red errors): Get-NetAdapter
# I recommend that you confirm your Intel NIC driver is up-to-date via your motherboard manufacturer's support website (or better yet your motherboard manufacturer's software, i.e. MSI Center, Armoury Crate, etc.). You will need to disable and re-enable your network adapter (or just restart your PC) for the below changes to take effect.
# I also recommend re-running this script every time you update your Intel Ethernet driver as there's a chance the settings could be reset to their default values.
# Lastly, it would be a good idea to confirm the below settings exist for your NIC by running the following PowerShell command and comparing the output to this script:
# Get-NetAdapterAdvancedProperty -Name "Ethernet" | Sort-Object "DisplayName"

# NOTE: These Registry settings are located in one of the subfolders located here: HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}

#Requires -RunAsAdministrator

# Disable Enable PME
Set-NetAdapterAdvancedProperty -Name "Ethernet" -RegistryKeyword "EnablePME" -RegistryValue 0
Write-Host "Enable PME has been disabled." -ForegroundColor Green

# Disable Large Send Offload v2 (IPv4)
Set-NetAdapterAdvancedProperty -Name "Ethernet" -RegistryKeyword "*LsoV2IPv4" -RegistryValue 0
Write-Host "Large Send Offload v2 (IPv4) has been disabled." -ForegroundColor Green

# Disable Large Send Offload v2 (IPv6)
Set-NetAdapterAdvancedProperty -Name "Ethernet" -RegistryKeyword "*LsoV2IPv6" -RegistryValue 0
Write-Host "Large Send Offload v2 (IPv6) has been disabled." -ForegroundColor Green

Write-Host "Successfully disabled Intel NIC settings." -ForegroundColor Green

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.