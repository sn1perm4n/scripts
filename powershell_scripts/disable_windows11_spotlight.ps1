# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables all Windows Spotlight features in Windows 11 and sets the desktop background to blank

#Requires -RunAsAdministrator

$hadErrors = $false

Write-Host "`nDisabling Windows Spotlight features..." -ForegroundColor Cyan

# Disable Spotlight on Lock Screen
Write-Host "`nDisabling Lock Screen Spotlight:" -ForegroundColor Cyan
$cdmPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
try {
	if (-not (Test-Path $cdmPath)) {
		New-Item -Path $cdmPath -Force | Out-Null
	}
	New-ItemProperty -Path $cdmPath -Name "RotatingLockScreenEnabled" -PropertyType DWord -Value 0 -Force | Out-Null
	New-ItemProperty -Path $cdmPath -Name "RotatingLockScreenOverlayEnabled" -PropertyType DWord -Value 0 -Force | Out-Null
	New-ItemProperty -Path $cdmPath -Name "SubscribedContent-338387Enabled" -PropertyType DWord -Value 0 -Force | Out-Null
	New-ItemProperty -Path $cdmPath -Name "SubscribedContent-338388Enabled" -PropertyType DWord -Value 0 -Force | Out-Null
	Write-Host "Lock Screen Spotlight disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Lock Screen Spotlight section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Disable Desktop Spotlight
Write-Host "`nDisabling Desktop Spotlight:" -ForegroundColor Cyan
$wallpaperSpotlightPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'
try {
	if (-not (Test-Path $wallpaperSpotlightPath)) {
		New-Item -Path $wallpaperSpotlightPath -Force | Out-Null
	}
	New-ItemProperty -Path $wallpaperSpotlightPath -Name "EnableDynamicContent" -PropertyType DWord -Value 0 -Force | Out-Null
	Write-Host "Desktop Spotlight disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Desktop Spotlight section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Disable Spotlight Tips, Ads, Fun Facts, Local Content
Write-Host "`nDisabling Spotlight Tips and Suggestions:" -ForegroundColor Cyan
try {
	New-ItemProperty -Path $cdmPath -Name "SubscribedContent-310093Enabled" -PropertyType DWord -Value 0 -Force | Out-Null
	New-ItemProperty -Path $cdmPath -Name "SubscribedContent-338389Enabled" -PropertyType DWord -Value 0 -Force | Out-Null
	New-ItemProperty -Path $cdmPath -Name "SubscribedContent-338393Enabled" -PropertyType DWord -Value 0 -Force | Out-Null
	New-ItemProperty -Path $cdmPath -Name "SubscribedContent-353694Enabled" -PropertyType DWord -Value 0 -Force | Out-Null
	New-ItemProperty -Path $cdmPath -Name "SubscribedContent-353695Enabled" -PropertyType DWord -Value 0 -Force | Out-Null
	New-ItemProperty -Path $cdmPath -Name "SubscribedContent-353696Enabled" -PropertyType DWord -Value 0 -Force | Out-Null
	New-ItemProperty -Path $cdmPath -Name "SubscribedContent-353697Enabled" -PropertyType DWord -Value 0 -Force | Out-Null
	New-ItemProperty -Path $cdmPath -Name "SubscribedContent-353698Enabled" -PropertyType DWord -Value 0 -Force | Out-Null
	Write-Host "Spotlight Tips, Fun Facts, and Local Content disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Tips and Local Content section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Disable Windows Cloud/Consumer Content
Write-Host "`nDisabling Cloud and Consumer Content:" -ForegroundColor Cyan
$cloudContentPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudContent'
try {
	if (-not (Test-Path $cloudContentPath)) {
		New-Item -Path $cloudContentPath -Force | Out-Null
	}
	New-ItemProperty -Path $cloudContentPath -Name "DisableWindowsConsumerFeatures" -PropertyType DWord -Value 1 -Force | Out-Null
	Write-Host "Cloud and Consumer Content disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Cloud/Consumer Content section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Hide the Windows Spotlight desktop icon
Write-Host "`nHiding Spotlight Desktop Icon:" -ForegroundColor Cyan
$advancedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
try {
	if (-not (Test-Path $advancedPath)) {
		New-Item -Path $advancedPath -Force | Out-Null
	}
	New-ItemProperty -Path $advancedPath -Name "ShowSpotlightDesktopIcon" -PropertyType DWord -Value 0 -Force | Out-Null
	Write-Host "Spotlight Desktop Icon hidden." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Spotlight Desktop Icon section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Hide the "Learn about this picture" Desktop icon
Write-Host "`nHiding 'Learn about this picture' Desktop Icon:" -ForegroundColor Cyan
$hidePicPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
try {
	if (-not (Test-Path $hidePicPath)) {
		New-Item -Path $hidePicPath -Force | Out-Null
	}
	New-ItemProperty -Path $hidePicPath -Name "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" -PropertyType DWord -Value 1 -Force | Out-Null
	Write-Host "'Learn about this picture' Desktop Icon hidden." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "'Learn about this picture' Desktop Icon section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Policy-based Spotlight disable (prevents re-enable)
Write-Host "`nDisabling Spotlight Policy Enforcement:" -ForegroundColor Cyan
$policyPath = 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent'
try {
	if (-not (Test-Path $policyPath)) {
		New-Item -Path $policyPath -Force | Out-Null
	}
	New-ItemProperty -Path $policyPath -Name "DisableSpotlightFeatures" -PropertyType DWord -Value 1 -Force | Out-Null
	New-ItemProperty -Path $policyPath -Name "DisableSpotlightOnLockScreen" -PropertyType DWord -Value 1 -Force | Out-Null
	New-ItemProperty -Path $policyPath -Name "DisableSpotlightSuggestions" -PropertyType DWord -Value 1 -Force | Out-Null
	Write-Host "Spotlight Policy Enforcement disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Policy Enforcement section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Disable Lock Screen Widgets (This Day in History, Weather, etc.)
Write-Host "`nDisabling Lock Screen Widgets (History, Weather, etc.)..." -ForegroundColor Cyan
try {
	$lockScreenPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen'
	if (-not (Test-Path $lockScreenPath)) {
		New-Item -Path $lockScreenPath -Force | Out-Null
	}
	New-ItemProperty -Path $lockScreenPath -Name "LockScreenWidgetsEnabled" -PropertyType DWord -Value 0 -Force | Out-Null
	Write-Host "Lock Screen widgets disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Lock Screen widgets section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Set desktop wallpaper to BLANK
Write-Host "`nDisabling Spotlight Desktop Wallpaper:" -ForegroundColor Cyan
$desktopPath = 'HKCU:\Control Panel\Desktop'
try {
	New-ItemProperty -Path $desktopPath -Name "Wallpaper" -PropertyType String -Value "" -Force | Out-Null
	# Force the wallpaper change to apply
	rundll32.exe user32.dll,UpdatePerUserSystemParameters
	Write-Host "Spotlight Wallpaper disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Desktop Wallpaper section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Sign out or restart File Explorer for all changes to take effect
Write-Host "`nSign out or restart File Explorer for all changes to take effect." -ForegroundColor Yellow

# Evaluate errors and return exit code
if ($hadErrors) {
	Write-Host "`nCompleted with errors." -ForegroundColor Red
	exit 1
}
else {
	Write-Host "`nCompleted successfully." -ForegroundColor Green
	exit 0
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.