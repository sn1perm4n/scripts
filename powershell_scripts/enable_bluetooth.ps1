# This script enables Bluetooth

Get-PnpDevice -Class Bluetooth | Enable-PnpDevice -Confirm:$false

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.