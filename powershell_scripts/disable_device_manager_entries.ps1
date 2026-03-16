# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables unnecessary devices (and deletes an invisible monitor) in Device Manager. Some devices get re-enabled (or reappear) every time the Nvidia driver is updated. To see invisible devices in Device Manager, go to the "View" menu and enable "Show hidden devices".

# IMPORTANT: It is unfortunately NOT possible to query the device status first so only enabled devices are processed. As a result, error-handling also can't be added. The only solution is to forcefully disable the devices every time the script runs (which is in no way harmful).

# NOTE: Under NO CIRCUMSTANCES should you delete every invisible device in Device Manager (unless you know EXACTLY what you're doing).

# Use the following command to dump output to a file for easy searching:
# Get-PnpDevice | Out-File -FilePath "C:\Users\<USERNAME>\Desktop\get-pnpdevices_output.txt"
# Can use the following command to prevent InstanceId from truncating:
# Get-PnpDevice | Format-Table -AutoSize -Wrap | Out-File -FilePath "C:\Users\<USERNAME>\Desktop\get-pnpdevices_output.txt"
# Can use the following command to only print non-truncated InstanceId column:
# Get-PnpDevice | Select-Object -ExpandProperty InstanceId | Out-File -FilePath "C:\Users\<USERNAME>\Desktop\get-pnpdevices_output.txt"
#Requires -RunAsAdministrator

# Ensure script runs as Administrator
$principal = New-Object Security.Principal.WindowsPrincipal `
	([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $principal.IsInRole(
	[Security.Principal.WindowsBuiltInRole]::Administrator
)) {
	Write-Host "Please run this script as Administrator. Press any key to exit..." -ForegroundColor Red
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit 1
}

# Realtek Digital Output (Realtek(R) Audio)
Get-PnpDevice -FriendlyName "Realtek Digital Output (Realtek(R) Audio)" | Disable-PnpDevice -Confirm:$false
Write-Host "Realtek Digital Output (Realtek(R) Audio) disabled." -ForegroundColor Green

# A-Volute Nh3 Audio Effects Component
Get-PnpDevice -FriendlyName "A-Volute Nh3 Audio Effects Component" | Disable-PnpDevice -Confirm:$false
Write-Host "A-Volute Nh3 Audio Effects Component disabled." -ForegroundColor Green

# Dell AW2518HF(DisplayPort)
# Invisible monitor entry after Nvidia Driver upgrade. InstanceId must be used for this since it shares the exact same name as the active Dell AW2518HF monitor. Furthermore, pnputil must be used in conjunction with Get-PnpDevice.
$dellMonitor = Get-PnpDevice -InstanceId "DISPLAY\DELA103\1&8713bca&0&UID0" -ErrorAction SilentlyContinue
if ($dellMonitor) {
	Get-PnpDevice -InstanceId "DISPLAY\DELA103\1&8713bca&0&UID0" | ForEach-Object { &"pnputil" /remove-device $_.InstanceId }
	Write-Host "Dell AW2518HF(DisplayPort) deleted." -ForegroundColor Green
} else {
	Write-Host "Dell AW2518HF(DisplayPort) not found." -ForegroundColor Yellow
}

# Nahimic Mirroring Component
Get-PnpDevice -FriendlyName "Nahimic Mirroring Component" | Disable-PnpDevice -Confirm:$false
Write-Host "Nahimic Mirroring Component disabled." -ForegroundColor Green

# Nahimic mirroring device
Get-PnpDevice -FriendlyName "Nahimic mirroring device" | Disable-PnpDevice -Confirm:$false
Write-Host "Nahimic mirroring device disabled." -ForegroundColor Green

# NVIDIA High Definition Audio
Get-PnpDevice -FriendlyName "NVIDIA High Definition Audio" | Disable-PnpDevice -Confirm:$false
Write-Host "NVIDIA High Definition Audio disabled." -ForegroundColor Green

# NVIDIA Virtual Audio Device (Wave Extensible) (WDM)
Get-PnpDevice -FriendlyName "NVIDIA Virtual Audio Device (Wave Extensible) (WDM)" | Disable-PnpDevice -Confirm:$false
Write-Host "NVIDIA Virtual Audio Device (Wave Extensible) (WDM) disabled." -ForegroundColor Green

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.