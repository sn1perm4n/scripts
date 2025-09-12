# This script disables unnecessary devices (and deletes an invisible monitor) in Device Manager. Some devices get re-enabled (or reappear) every time the Nvidia driver is updated. To see invisible devices in Device Manager, go to the "View" menu and enable "Show hidden devices".

# NOTE: Under NO CIRCUMSTANCES should you delete every invisible device in Device Manager (unless you know EXACTLY what you're doing).

# Use the following command to dump output to a file for easy searching:
# Get-PnpDevice | Out-File -FilePath "C:\Users\<PROFILE>\Desktop\get-pnpdevices_output.txt"
# Can use the following command to prevent InstanceId from truncating:
# Get-PnpDevice | Format-Table -AutoSize -Wrap | Out-File -FilePath "C:\Users\<PROFILE>\Desktop\get-pnpdevices_output.txt"
# Can use the following command to only print non-truncated InstanceId column:
# Get-PnpDevice | Select-Object -ExpandProperty InstanceId | Out-File -FilePath "C:\Users\<PROFILE>\Desktop\get-pnpdevices_output.txt"

# Realtek Digital Output (Realtek(R) Audio)
Get-PnpDevice -FriendlyName "Realtek Digital Output (Realtek(R) Audio)" | Disable-PnpDevice -Confirm:$false
Write-Host "Realtek Digital Output (Realtek(R) Audio) disabled."

# A-Volute Nh3 Audio Effects Component
Get-PnpDevice -FriendlyName "A-Volute Nh3 Audio Effects Component" | Disable-PnpDevice -Confirm:$false
Write-Host "A-Volute Nh3 Audio Effects Component disabled."

# Dell AW2518HF(DisplayPort)
# Invisible monitor entry after Nvidia Driver upgrade. InstanceId must be used for this since it shares the exact same name as the active Dell AW2518HF monitor. Furthermore, pnputil must be used in conjunction with Get-PnpDevice.
$dellMonitor = Get-PnpDevice -InstanceId "DISPLAY\DELA103\1&8713bca&0&UID0" -ErrorAction SilentlyContinue
if ($dellMonitor) {
	Get-PnpDevice -InstanceId "DISPLAY\DELA103\1&8713bca&0&UID0" | ForEach-Object { &"pnputil" /remove-device $_.InstanceId }
	Write-Host "Dell AW2518HF(DisplayPort) deleted."
} else {
	Write-Host "Dell AW2518HF(DisplayPort) not found."
}

# Nahimic Mirroring Component
Get-PnpDevice -FriendlyName "Nahimic Mirroring Component" | Disable-PnpDevice -Confirm:$false
Write-Host "Nahimic Mirroring Component disabled."

# Nahimic mirroring device
Get-PnpDevice -FriendlyName "Nahimic mirroring device" | Disable-PnpDevice -Confirm:$false
Write-Host "Nahimic mirroring device disabled."

# NVIDIA High Definition Audio
Get-PnpDevice -FriendlyName "NVIDIA High Definition Audio" | Disable-PnpDevice -Confirm:$false
Write-Host "NVIDIA High Definition Audio disabled."

# NVIDIA Virtual Audio Device (Wave Extensible) (WDM)
Get-PnpDevice -FriendlyName "NVIDIA Virtual Audio Device (Wave Extensible) (WDM)" | Disable-PnpDevice -Confirm:$false
Write-Host "NVIDIA Virtual Audio Device (Wave Extensible) (WDM) disabled."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.