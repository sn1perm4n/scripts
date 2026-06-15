# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables unnecessary devices (and deletes an invisible monitor) in Device Manager. Some devices get re-enabled (or reappear) every time the Nvidia driver is updated. To see invisible devices in Device Manager, go to the "View" menu and enable "Show hidden devices".

# NOTE: Under NO CIRCUMSTANCES should you delete every invisible device in Device Manager (unless you know EXACTLY what you're doing)

# Use the following command to dump output to a file for easy searching:
# Get-PnpDevice | Out-File -FilePath "C:\Users\<username>\Desktop\get-pnpdevices_output.txt"
# Can use the following command to prevent InstanceId from truncating:
# Get-PnpDevice | Format-Table -AutoSize -Wrap | Out-File -FilePath "C:\Users\<USERNAME>\Desktop\get-pnpdevices_output.txt"
# Can use the following command to only print non-truncated InstanceId column:
# Get-PnpDevice | Select-Object -ExpandProperty InstanceId | Out-File -FilePath "C:\Users\<USERNAME>\Desktop\get-pnpdevices_output.txt"

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

Write-Host ""

$disabledCount = 0
$alreadyDisabledCount = 0
$notFoundCount = 0

# Realtek Digital Output (Realtek(R) Audio)
$device = Get-PnpDevice -FriendlyName "Realtek Digital Output (Realtek(R) Audio)" -ErrorAction SilentlyContinue
if ($device) {
	if ($device.Status -eq 'Error' -or $device.Status -eq 'Unknown') {
		Write-Host "Already disabled: Realtek Digital Output (Realtek(R) Audio)" -ForegroundColor Yellow
		$alreadyDisabledCount++
	}
	else {
		$device | Disable-PnpDevice -Confirm:$false
		Write-Host "Disabled: Realtek Digital Output (Realtek(R) Audio)" -ForegroundColor Green
		$disabledCount++
	}
}
else {
	Write-Host "Not found: Realtek Digital Output (Realtek(R) Audio)" -ForegroundColor Yellow
	$notFoundCount++
}

# A-Volute Nh3 Audio Effects Component
$device = Get-PnpDevice -FriendlyName "A-Volute Nh3 Audio Effects Component" -ErrorAction SilentlyContinue
if ($device) {
	if ($device.Status -eq 'Error' -or $device.Status -eq 'Unknown') {
		Write-Host "Already disabled: A-Volute Nh3 Audio Effects Component" -ForegroundColor Yellow
		$alreadyDisabledCount++
	}
	else {
		$device | Disable-PnpDevice -Confirm:$false
		Write-Host "Disabled: A-Volute Nh3 Audio Effects Component" -ForegroundColor Green
		$disabledCount++
	}
}
else {
	Write-Host "Not found: A-Volute Nh3 Audio Effects Component" -ForegroundColor Yellow
	$notFoundCount++
}

# Dell AW2518HF(DisplayPort)
# Invisible monitor entry after Nvidia Driver upgrade. InstanceId must be used for this since it shares the exact same name as the active Dell AW2518HF monitor. Furthermore, pnputil must be used in conjunction with Get-PnpDevice.
$dellMonitor = Get-PnpDevice -InstanceId "DISPLAY\DELA103\1&8713bca&0&UID0" -ErrorAction SilentlyContinue
if ($dellMonitor) {
	$dellMonitor | ForEach-Object { &"pnputil" /remove-device $_.InstanceId }
	Write-Host "Deleted: Dell AW2518HF(DisplayPort)" -ForegroundColor Green
	$disabledCount++
}
else {
	Write-Host "Not found: Dell AW2518HF(DisplayPort)" -ForegroundColor Yellow
	$notFoundCount++
}

# Nahimic Mirroring Component
$device = Get-PnpDevice -FriendlyName "Nahimic Mirroring Component" -ErrorAction SilentlyContinue
if ($device) {
	if ($device.Status -eq 'Error' -or $device.Status -eq 'Unknown') {
		Write-Host "Already disabled: Nahimic Mirroring Component" -ForegroundColor Yellow
		$alreadyDisabledCount++
	}
	else {
		$device | Disable-PnpDevice -Confirm:$false
		Write-Host "Disabled: Nahimic Mirroring Component" -ForegroundColor Green
		$disabledCount++
	}
}
else {
	Write-Host "Not found: Nahimic Mirroring Component" -ForegroundColor Yellow
	$notFoundCount++
}

# Nahimic mirroring device
$device = Get-PnpDevice -FriendlyName "Nahimic mirroring device" -ErrorAction SilentlyContinue
if ($device) {
	if ($device.Status -eq 'Error' -or $device.Status -eq 'Unknown') {
		Write-Host "Already disabled: Nahimic mirroring device" -ForegroundColor Yellow
		$alreadyDisabledCount++
	}
	else {
		$device | Disable-PnpDevice -Confirm:$false
		Write-Host "Disabled: Nahimic mirroring device" -ForegroundColor Green
		$disabledCount++
	}
}
else {
	Write-Host "Not found: Nahimic mirroring device" -ForegroundColor Yellow
	$notFoundCount++
}

# NVIDIA High Definition Audio
$device = Get-PnpDevice -FriendlyName "NVIDIA High Definition Audio" -ErrorAction SilentlyContinue
if ($device) {
	if ($device.Status -eq 'Error' -or $device.Status -eq 'Unknown') {
		Write-Host "Already disabled: NVIDIA High Definition Audio" -ForegroundColor Yellow
		$alreadyDisabledCount++
	}
	else {
		$device | Disable-PnpDevice -Confirm:$false
		Write-Host "Disabled: NVIDIA High Definition Audio" -ForegroundColor Green
		$disabledCount++
	}
}
else {
	Write-Host "Not found: NVIDIA High Definition Audio" -ForegroundColor Yellow
	$notFoundCount++
}

# NVIDIA Virtual Audio Device (Wave Extensible) (WDM)
$device = Get-PnpDevice -FriendlyName "NVIDIA Virtual Audio Device (Wave Extensible) (WDM)" -ErrorAction SilentlyContinue
if ($device) {
	if ($device.Status -eq 'Error' -or $device.Status -eq 'Unknown') {
		Write-Host "Already disabled: NVIDIA Virtual Audio Device (Wave Extensible) (WDM)" -ForegroundColor Yellow
		$alreadyDisabledCount++
	}
	else {
		$device | Disable-PnpDevice -Confirm:$false
		Write-Host "Disabled: NVIDIA Virtual Audio Device (Wave Extensible) (WDM)" -ForegroundColor Green
		$disabledCount++
	}
}
else {
	Write-Host "Not found: NVIDIA Virtual Audio Device (Wave Extensible) (WDM)" -ForegroundColor Yellow
	$notFoundCount++
}

$summaryLine = "$ScriptName`: $disabledCount device(s) disabled/deleted, $alreadyDisabledCount already disabled, $notFoundCount not found."
Write-Host "`n$summaryLine" -ForegroundColor $(if ($disabledCount -gt 0) { 'Green' } else { 'Yellow' })

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.