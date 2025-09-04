# This script disables Bluetooth

Get-PnpDevice -Class Bluetooth | Disable-PnpDevice -Confirm:$false

Write-Host "Successfully disabled Bluetooth."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.