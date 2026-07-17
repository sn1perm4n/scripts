# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables AI features in Windows 11, and also fully disables Widgets (which includes an AI-curated news feed alongside its non-AI content)

# IMPORTANT: Please read the OneDrive and Recall comments later in this script as they could directly impact you

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

$hadErrors = $false

Write-Host "`nDisabling Windows 11 AI features..." -ForegroundColor Cyan

# Disable Windows Copilot
Write-Host "`nDisabling Windows Copilot..." -ForegroundColor Cyan
$copilotPaths = @(
	'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot',
	'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'
)

try {
	foreach ($path in $copilotPaths) {
		New-Item -Path $path -Force | Out-Null
		New-ItemProperty -Path $path -Name "TurnOffWindowsCopilot" -Type DWord -Value 1 -Force | Out-Null
	}

	# Disable Copilot button and shortcut
	$explorerAdvancedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
	New-ItemProperty -Path $explorerAdvancedPath -Name "ShowCopilotButton" -Type DWord -Value 0 -Force | Out-Null

	# Prevent Windows Update from reprovisioning the Copilot app (added April 2026 Update)
	$windowsAiPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
	New-Item -Path $windowsAiPath -Force | Out-Null
	New-ItemProperty -Path $windowsAiPath -Name "RemoveMicrosoftCopilotApp" -Type DWord -Value 1 -Force | Out-Null

	# Remove Windows Copilot package for current user
	$copilotPackage = Get-AppxPackage -Name '*Copilot*'
	if ($copilotPackage) {
		Remove-AppxPackage $copilotPackage.PackageFullName
		Write-Host "Copilot package removed for current user." -ForegroundColor Green
	}
	else {
		Write-Host "No Copilot package found for current user." -ForegroundColor Green
	}

	Write-Host "Windows Copilot disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Windows Copilot section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Disable Windows Recall (if present)
Write-Host "`nDisabling Windows Recall..." -ForegroundColor Cyan
try {
	$recallPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
	New-Item -Path $recallPath -Force | Out-Null
	New-ItemProperty -Path $recallPath -Name "DisableAIDataAnalysis" -Type DWord -Value 1 -Force | Out-Null
	New-ItemProperty -Path $recallPath -Name "AllowRecallEnablement" -Type DWord -Value 0 -Force | Out-Null
	Write-Host "Windows Recall disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Windows Recall section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Disable Click to Do (Copilot+ PC feature; harmless no-op on non-Copilot+ hardware)
Write-Host "`nDisabling Click to Do..." -ForegroundColor Cyan
try {
	$clickToDoPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
	New-Item -Path $clickToDoPath -Force | Out-Null
	New-ItemProperty -Path $clickToDoPath -Name "DisableClickToDo" -Type DWord -Value 1 -Force | Out-Null
	Write-Host "Click to Do disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Click to Do section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Disable AI Agents in the Settings app (agentic search experience)
Write-Host "`nDisabling Settings app AI Agent..." -ForegroundColor Cyan
try {
	$settingsAgentPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
	New-Item -Path $settingsAgentPath -Force | Out-Null
	New-ItemProperty -Path $settingsAgentPath -Name "DisableSettingsAgent" -Type DWord -Value 1 -Force | Out-Null
	Write-Host "Settings app AI Agent disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Settings app AI Agent section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Disable AI-powered Search/Bing integration
Write-Host "`nDisabling AI-powered Search and Bing integration..." -ForegroundColor Cyan
try {
	$searchPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
	$searchValues = @(
		'BingSearchEnabled',
		'CortanaConsent',
		'AllowSearchToUseLocation'
	)

	foreach ($name in $searchValues) {
		New-ItemProperty -Path $searchPath -Name $name -Type DWord -Value 0 -Force | Out-Null
	}

	# Policy-level search disable
	$searchPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
	New-Item -Path $searchPolicy -Force | Out-Null
	New-ItemProperty -Path $searchPolicy -Name "DisableWebSearch" -Type DWord -Value 1 -Force | Out-Null
	New-ItemProperty -Path $searchPolicy -Name "ConnectedSearchUseWeb" -Type DWord -Value 0 -Force | Out-Null

	# Disable Search Highlights (taskbar AI tips and trending content)
	$explorerPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
	New-Item -Path $explorerPolicyPath -Force | Out-Null
	New-ItemProperty -Path $explorerPolicyPath -Name "DisableSearchHighlight" -Type DWord -Value 1 -Force | Out-Null

	Write-Host "AI-powered Search and Bing integration disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Search and Bing section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Disable Widgets (AI-backed feeds)
Write-Host "`nDisabling Widgets..." -ForegroundColor Cyan
try {
	$widgetsPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
	New-Item -Path $widgetsPath -Force | Out-Null
	New-ItemProperty -Path $widgetsPath -Name "AllowWidgets" -Type DWord -Value 0 -Force | Out-Null
	New-ItemProperty -Path $widgetsPath -Name "AllowNewsAndInterests" -Type DWord -Value 0 -Force | Out-Null
	Write-Host "Widgets disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Widgets section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Disable Consumer AI/Cloud Experiences
Write-Host "`nDisabling Consumer AI and Cloud Experiences..." -ForegroundColor Cyan
try {
	$cloudContent = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
	New-Item -Path $cloudContent -Force | Out-Null

	$cloudValues = @(
		'DisableWindowsConsumerFeatures',
		'DisableCloudOptimizedContent',
		'DisableTailoredExperiencesWithDiagnosticData'
	)

	foreach ($value in $cloudValues) {
		New-ItemProperty -Path $cloudContent -Name $value -Type DWord -Value 1 -Force | Out-Null
	}

	Write-Host "Consumer AI and Cloud Experiences disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Consumer AI/Cloud Experiences section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# OPTIONAL: Disable OneDrive consumer features (disables AI photo indexing, insights, and cloud analysis)
# IMPORTANT: PLEASE NOTE THE FOLLOWING SECTION COMPLETELY DISABLES ONEDRIVE FOR CONSUMER USE. IF YOU HAVE NO INTENTION OF USING ONEDRIVE, UNCOMMENT THE THREE LINES BELOW THIS COMMENT BEFORE RUNNING THIS SCRIPT. I'd also recommend uninstalling OneDrive as well if you have no intention of using it.
# $oneDrivePolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'
# New-Item -Path $oneDrivePolicy -Force | Out-Null
# New-ItemProperty -Path $oneDrivePolicy -Name "DisablePersonalSync" -Type DWord -Value 1 -Force | Out-Null

# OPTIONAL: Remove the Recall optional feature entirely (goes further than the WindowsAI policy above)
# IMPORTANT: THIS REQUIRES A RESTART AND ONLY APPLIES ON COPILOT+ PCS WHERE RECALL IS PRESENT. IF YOU
# WANT TO GO BEYOND THE POLICY-LEVEL DISABLE AND REMOVE THE FEATURE'S PAYLOAD FROM THE SYSTEM, UNCOMMENT
# THE LINE BELOW. TO REVERSE, RUN: Dism /Online /Enable-Feature /FeatureName:"Recall"
# Dism /Online /Disable-Feature /FeatureName:"Recall" /NoRestart

# Reduce AI-related telemetry
# NOTE: On Windows 11 Home and Pro (as opposed to Enterprise/Education/Server), setting
# AllowTelemetry to 0 ("Security") is silently floored to 1 ("Required diagnostic data") by
# Windows regardless of the value written here. This is harmless and not something this script
# can work around — it's an OS-enforced edition restriction. On Enterprise/Education/Server,
# this value of 0 is honored as-is.
Write-Host "`nReducing AI-related telemetry..." -ForegroundColor Cyan
try {
	$telemetryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
	New-Item -Path $telemetryPath -Force | Out-Null
	New-ItemProperty -Path $telemetryPath -Name "AllowTelemetry" -Type DWord -Value 0 -Force | Out-Null
	Write-Host "AI-related telemetry reduced." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Telemetry section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Disable Image Creator in Microsoft Paint
# NOTE: Generative Erase and Remove Background currently have no disable policy from
# Microsoft and are not affected by anything in this section.
Write-Host "`nDisabling Image Creator in Microsoft Paint..." -ForegroundColor Cyan
try {
	$paintPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'
	if (-not (Test-Path $paintPath)) {
		New-Item -Path $paintPath -Force | Out-Null
	}
	New-ItemProperty -Path $paintPath -Name "DisableImageCreator" -Type DWord -Value 1 -Force | Out-Null
	New-ItemProperty -Path $paintPath -Name "DisableCocreator" -Type DWord -Value 1 -Force | Out-Null
	New-ItemProperty -Path $paintPath -Name "DisableGenerativeFill" -Type DWord -Value 1 -Force | Out-Null
	Write-Host "Image Creator, Cocreator, and Generative Fill in Microsoft Paint disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Microsoft Paint section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Disable AI features (Rewrite, Summarize, etc.) in Notepad
Write-Host "`nDisabling AI features in Notepad..." -ForegroundColor Cyan
try {
	$notepadPolicyPath = 'HKLM:\SOFTWARE\Policies\WindowsNotepad'
	New-Item -Path $notepadPolicyPath -Force | Out-Null
	New-ItemProperty -Path $notepadPolicyPath -Name "DisableAIFeatures" -Type DWord -Value 1 -Force | Out-Null
	Write-Host "AI features in Notepad disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Notepad section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Disable AI and Bing features in Microsoft Edge
Write-Host "`nDisabling AI and Bing features in Microsoft Edge..." -ForegroundColor Cyan
try {
	$edgePolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
	New-Item -Path $edgePolicy -Force | Out-Null

	# Disable Bing AI/Chat features
	New-ItemProperty -Path $edgePolicy -Name "SearchAssistantEnabled" -Type DWord -Value 0 -Force | Out-Null
	New-ItemProperty -Path $edgePolicy -Name "SearchAssistantOverridesEnabled" -Type DWord -Value 0 -Force | Out-Null
	New-ItemProperty -Path $edgePolicy -Name "SearchAssistantEnabledInPrivate" -Type DWord -Value 0 -Force | Out-Null

	# Disable Bing suggestions and predictive services
	New-ItemProperty -Path $edgePolicy -Name "BingSearchEnabled" -Type DWord -Value 0 -Force | Out-Null
	New-ItemProperty -Path $edgePolicy -Name "EnableBingPredictiveServices" -Type DWord -Value 0 -Force | Out-Null

	# Disable Collections AI/sidebar suggestions
	New-ItemProperty -Path $edgePolicy -Name "CollectionsEnabled" -Type DWord -Value 0 -Force | Out-Null

	Write-Host "AI and Bing features in Microsoft Edge disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Microsoft Edge section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# Summary
if ($hadErrors) {
	Write-Host ""
	Write-Error "$ScriptName`: AI features disabled with errors — some settings may not have taken effect. A reboot is required."
	exit 1
}
else {
	Write-Host "`n$ScriptName`: AI features disabled successfully. A reboot is required." -ForegroundColor Green
	exit 0
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.