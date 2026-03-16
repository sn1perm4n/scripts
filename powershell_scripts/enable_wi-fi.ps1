# This script enables Wi-Fi

Enable-NetAdapter -Name "Wi-Fi" -Confirm:$false

Write-Host "Successfully enabled Wi-Fi."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.