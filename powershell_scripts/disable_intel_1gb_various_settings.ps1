# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables various settings on a Intel 1Gb Ethernet card that negatively impact performance (especially for gaming). The name of your Ethernet adapter may differ (i.e. on one of my systems it's "Local Area Connection") so confirm first with the following PowerShell command (if you don't do this you'll see a bunch of red errors):
# Get-NetAdapter
# I recommend that you confirm your Intel NIC driver is up-to-date via your motherboard manufacturer's support website (or better yet your motherboard manufacturer's software, i.e. MSI Center, Armoury Crate, etc.). You will need to disable and re-enable your network adapter (or just restart your PC) for the below changes to take effect.
# I also recommend re-running this script every time you update your Intel Ethernet driver as there's a chance the settings could be reset to their default values
# Lastly, it would be a good idea to confirm the below settings exist for your NIC by running the following PowerShell command and comparing the output to this script:
# Get-NetAdapterAdvancedProperty -Name "Ethernet" | Sort-Object "DisplayName"

# NOTE: These Registry settings are located in one of the subfolders located here: HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}

#Requires -RunAsAdministrator

Write-Host "`nChecking Intel 1Gb NIC settings..." -ForegroundColor Cyan

# Disable Enable PME
try {
	Set-NetAdapterAdvancedProperty -Name "Ethernet" -RegistryKeyword "EnablePME" -RegistryValue 0 -ErrorAction Stop
	Write-Host "`nEnable PME has been disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Could not disable Enable PME: $($_.Exception.Message)"
}

# Disable Energy-Efficient Ethernet
try {
	Set-NetAdapterAdvancedProperty -Name "Ethernet" -RegistryKeyword "EEELinkAdvertisement" -RegistryValue 0 -ErrorAction Stop
	Write-Host "Energy-Efficient Ethernet has been disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Could not disable Energy-Efficient Ethernet: $($_.Exception.Message)"
}

# Disable Large Send Offload v2 (IPv4)
try {
	Set-NetAdapterAdvancedProperty -Name "Ethernet" -RegistryKeyword "*LsoV2IPv4" -RegistryValue 0 -ErrorAction Stop
	Write-Host "Large Send Offload v2 (IPv4) has been disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Could not disable Large Send Offload v2 (IPv4): $($_.Exception.Message)"
}

# Disable Large Send Offload v2 (IPv6)
try {
	Set-NetAdapterAdvancedProperty -Name "Ethernet" -RegistryKeyword "*LsoV2IPv6" -RegistryValue 0 -ErrorAction Stop
	Write-Host "Large Send Offload v2 (IPv6) has been disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Could not disable Large Send Offload v2 (IPv6): $($_.Exception.Message)"
}

Write-Host "`nSuccessfully disabled Intel 1Gb NIC settings." -ForegroundColor Green

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.