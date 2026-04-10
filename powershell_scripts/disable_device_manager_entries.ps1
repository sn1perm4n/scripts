# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables unnecessary devices (and deletes an invisible monitor) in Device Manager. Some devices get re-enabled (or reappear) every time the Nvidia driver is updated. To see invisible devices in Device Manager, go to the "View" menu and enable "Show hidden devices".

# IMPORTANT: It is unfortunately NOT possible to query the device status first so only enabled devices are processed. As a result, error-handling also can't be added. The only solution is to individually query the devices every time the script runs (which is in no way harmful).

# NOTE: Under NO CIRCUMSTANCES should you delete every invisible device in Device Manager (unless you know EXACTLY what you're doing).

# Use the following command to dump output to a file for easy searching:
# Get-PnpDevice | Out-File -FilePath "C:\Users\<username>\Desktop\get-pnpdevices_output.txt"
# Can use the following command to prevent InstanceId from truncating:
# Get-PnpDevice | Format-Table -AutoSize -Wrap | Out-File -FilePath "C:\Users\<USERNAME>\Desktop\get-pnpdevices_output.txt"
# Can use the following command to only print non-truncated InstanceId column:
# Get-PnpDevice | Select-Object -ExpandProperty InstanceId | Out-File -FilePath "C:\Users\<USERNAME>\Desktop\get-pnpdevices_output.txt"

#Requires -RunAsAdministrator

# Realtek Digital Output (Realtek(R) Audio)
$device = Get-PnpDevice -FriendlyName "Realtek Digital Output (Realtek(R) Audio)" -ErrorAction SilentlyContinue
if ($device) {
	$device | Disable-PnpDevice -Confirm:$false
	Write-Host "Realtek Digital Output (Realtek(R) Audio) disabled." -ForegroundColor Green
}
else {
	Write-Host "Realtek Digital Output (Realtek(R) Audio) not found." -ForegroundColor Yellow
}

# A-Volute Nh3 Audio Effects Component
$device = Get-PnpDevice -FriendlyName "A-Volute Nh3 Audio Effects Component" -ErrorAction SilentlyContinue
if ($device) {
	$device | Disable-PnpDevice -Confirm:$false
	Write-Host "A-Volute Nh3 Audio Effects Component disabled." -ForegroundColor Green
}
else {
	Write-Host "A-Volute Nh3 Audio Effects Component not found." -ForegroundColor Yellow
}

# Dell AW2518HF(DisplayPort)
# Invisible monitor entry after Nvidia Driver upgrade. InstanceId must be used for this since it shares the exact same name as the active Dell AW2518HF monitor. Furthermore, pnputil must be used in conjunction with Get-PnpDevice.
$dellMonitor = Get-PnpDevice -InstanceId "DISPLAY\DELA103\1&8713bca&0&UID0" -ErrorAction SilentlyContinue
if ($dellMonitor) {
	$dellMonitor | ForEach-Object { &"pnputil" /remove-device $_.InstanceId }
	Write-Host "Dell AW2518HF(DisplayPort) deleted." -ForegroundColor Green
}
else {
	Write-Host "Dell AW2518HF(DisplayPort) not found." -ForegroundColor Yellow
}

# Nahimic Mirroring Component
$device = Get-PnpDevice -FriendlyName "Nahimic Mirroring Component" -ErrorAction SilentlyContinue
if ($device) {
	$device | Disable-PnpDevice -Confirm:$false
	Write-Host "Nahimic Mirroring Component disabled." -ForegroundColor Green
}
else {
	Write-Host "Nahimic Mirroring Component not found." -ForegroundColor Yellow
}

# Nahimic mirroring device
$device = Get-PnpDevice -FriendlyName "Nahimic mirroring device" -ErrorAction SilentlyContinue
if ($device) {
	$device | Disable-PnpDevice -Confirm:$false
	Write-Host "Nahimic mirroring device disabled." -ForegroundColor Green
}
else {
	Write-Host "Nahimic mirroring device not found." -ForegroundColor Yellow
}

# NVIDIA High Definition Audio
$device = Get-PnpDevice -FriendlyName "NVIDIA High Definition Audio" -ErrorAction SilentlyContinue
if ($device) {
	$device | Disable-PnpDevice -Confirm:$false
	Write-Host "NVIDIA High Definition Audio disabled." -ForegroundColor Green
}
else {
	Write-Host "NVIDIA High Definition Audio not found." -ForegroundColor Yellow
}

# NVIDIA Virtual Audio Device (Wave Extensible) (WDM)
$device = Get-PnpDevice -FriendlyName "NVIDIA Virtual Audio Device (Wave Extensible) (WDM)" -ErrorAction SilentlyContinue
if ($device) {
	$device | Disable-PnpDevice -Confirm:$false
	Write-Host "NVIDIA Virtual Audio Device (Wave Extensible) (WDM) disabled." -ForegroundColor Green
}
else {
	Write-Host "NVIDIA Virtual Audio Device (Wave Extensible) (WDM) not found." -ForegroundColor Yellow
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.