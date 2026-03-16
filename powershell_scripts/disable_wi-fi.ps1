# This script disables Wi-Fi

Disable-NetAdapter -Name "Wi-Fi" -Confirm:$false

Write-Host "Successfully disabled Wi-Fi."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.