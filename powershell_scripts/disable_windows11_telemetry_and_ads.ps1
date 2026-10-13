# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables various settings in Windows 11 that relate to advertising/marketing, tracking, annoying widgets, search highlights, unwanted tips, Bing web search integration, cloud content suggestions, Windows Spotlight, etc.

# NOTE: Some Windows Registry keys aren't being checked/created because they're guaranteed to exist in a fresh install

# NOTE2: The HKCU (HKEY_CURRENT_USER) settings only apply to the account running this script, while the HKLM (HKEY_LOCAL_MACHINE) policies, the DiagTrack service, and the scheduled tasks are machine-wide. Therefore this script must not be run as a Group Policy Object (GPO) Computer Startup script (where HKCU resolves to SYSTEM's own profile), nor elevated under a different administrator account than the intended user's.

# NOTE3: -Backup captures every registry value listed in $managedSettings (plus the DiagTrack service and the Customer Experience Improvement Program (CEIP) scheduled tasks) regardless of -Exclude, and -Restore puts them back, deleting any value that did not exist at backup time. The Copilot package removal cannot be restored by this script (reinstall it from the Microsoft Store). $managedSettings must be kept in sync with the registry writes in the sections below, since -Backup, -Restore, and -Preview read it.

# NOTE4: Section names accepted by -Exclude: DiagTrack, SyncProviderNotifications, Widgets, SearchHighlightsBing, ContentDeliveryManager, SearchHistory, SearchHighlightsPolicy, Spotlight, GameBar, SuggestWays, Copilot, StartRecommendations, AdvertisingID, LanguageList, AppLaunchTracking, CEIP

# Optional flags:
#     -Backup <PATH>:      Save the current state of every setting this script changes (registry values, the DiagTrack service, and the Customer Experience Improvement Program scheduled tasks) to a CSV file before making changes
#     -Exclude <NAME,...>: Comma-separated section names to skip (i.e. Widgets,Copilot); see NOTE4 for the valid names
#     -NoConsoleOutput:    Suppress console output (requires -SaveResults)
#     -Preview:            Show the current and proposed value of every setting without making any changes (mutually exclusive with -Restore)
#     -Restore <PATH>:     Restore settings from a -Backup CSV file instead of disabling anything (mutually exclusive with -Preview)
#     -SaveResults <PATH>: Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)
#     -Help / -?:          Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[string]$Backup,
	[string]$Exclude,
	[switch]$NoConsoleOutput,
	[switch]$Preview,
	[string]$Restore,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup <PATH>] [-Exclude <NAME,...>] [-NoConsoleOutput] [-Preview] [-Restore <PATH>] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup <PATH>      Save the current state of every setting this script changes (registry values, the DiagTrack service, and the Customer Experience Improvement Program scheduled tasks) to a CSV file before making changes" -ForegroundColor Cyan
	Write-Host "  -Exclude <NAME,...> Comma-separated section names to skip (i.e. Widgets,Copilot); see the section names below" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput    Suppress console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Preview            Show the current and proposed value of every setting without making any changes (mutually exclusive with -Restore)" -ForegroundColor Cyan
	Write-Host "  -Restore <PATH>     Restore settings from a -Backup CSV file instead of disabling anything (mutually exclusive with -Preview)" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH> Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)" -ForegroundColor Cyan
	Write-Host "  -Help               Display this help message" -ForegroundColor Cyan
	Write-Host "`nSection names for -Exclude:" -ForegroundColor Cyan
	Write-Host "  DiagTrack, SyncProviderNotifications, Widgets, SearchHighlightsBing, ContentDeliveryManager, SearchHistory, SearchHighlightsPolicy, Spotlight, GameBar, SuggestWays, Copilot, StartRecommendations, AdvertisingID, LanguageList, AppLaunchTracking, CEIP" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# -NoConsoleOutput requires -SaveResults, since without it there's nowhere to record results
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults."
	exit 1
}

# -Preview and -Restore are mutually exclusive, since -Preview changes nothing while -Restore reverses earlier changes
if ($Preview -and $Restore) {
	Write-Host ""
	Write-Error "-Preview and -Restore are mutually exclusive."
	exit 1
}

# -Restore requires the backup file to already exist, since it's read from rather than written to
if ($Restore -and -not (Test-Path -LiteralPath $Restore)) {
	Write-Host ""
	Write-Error "-Restore file not found: '$Restore'"
	exit 1
}

# Section names, in the order the sections run below; -Exclude is validated against this list
$validSections = @('DiagTrack', 'SyncProviderNotifications', 'Widgets', 'SearchHighlightsBing', 'ContentDeliveryManager', 'SearchHistory', 'SearchHighlightsPolicy', 'Spotlight', 'GameBar', 'SuggestWays', 'Copilot', 'StartRecommendations', 'AdvertisingID', 'LanguageList', 'AppLaunchTracking', 'CEIP')

$excludedSections = @()
if ($Exclude) {
	$excludedSections = @($Exclude -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
	$unknownSections = @($excludedSections | Where-Object { $validSections -notcontains $_ })
	if ($unknownSections.Count -gt 0) {
		Write-Host ""
		Write-Error "Unknown section name(s) for -Exclude: $($unknownSections -join ', '). Valid names: $($validSections -join ', ')"
		exit 1
	}
}

# Validate the -Backup and -SaveResults paths up front, so a bad path doesn't surface only after every change has been made
foreach ($savePath in @($Backup, $SaveResults)) {
	if ($savePath) {
		$saveDir = Split-Path $savePath -Parent
		if ($saveDir -and -not (Test-Path $saveDir)) {
			Write-Host ""
			Write-Error "The directory for save path does not exist: '$saveDir'"
			exit 1
		}
	}
}

# Write the hostname as a header line the first time -SaveResults is created, so a fleet of per-machine files can be identified at a glance
if ($SaveResults -and -not (Test-Path $SaveResults)) {
	try {
		[System.IO.File]::AppendAllText($SaveResults, "$env:COMPUTERNAME`:`n")
	}
	catch {
		Write-Host ""
		Write-Warning "Could not write hostname header to '$SaveResults': $($_.Exception.Message)"
	}
}

$hadErrors = $false
$FileOutputLines = @()

if ($excludedSections.Count -gt 0) {
	$excludeLine = "Excluding sections: $($excludedSections -join ', ')"
	if (-not $NoConsoleOutput) { Write-Host "`n$excludeLine" -ForegroundColor Yellow }
	$FileOutputLines += $excludeLine
}

# CEIP scheduled task folder, shared by the backup/preview/restore logic and the CEIP section below
$ceipPath = "\Microsoft\Windows\Customer Experience Improvement Program\"

# Every registry value this script sets, read by -Backup, -Restore, and -Preview (see NOTE3)
$managedSettings = @(
	[PSCustomObject]@{ Section = 'SyncProviderNotifications'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowSyncProviderNotifications'; Value = 0 }
	[PSCustomObject]@{ Section = 'Widgets'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowWidgets'; Value = 0 }
	[PSCustomObject]@{ Section = 'Widgets'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Value = 0 }
	[PSCustomObject]@{ Section = 'SearchHighlightsBing'; Path = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchBoxSuggestions'; Value = 1 }
	[PSCustomObject]@{ Section = 'SearchHighlightsBing'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name = 'IsDynamicSearchBoxEnabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'SearchHighlightsBing'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name = 'IsCloudSearchEnabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'SearchHighlightsBing'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name = 'IsMSACloudSearchEnabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'ContentDeliveryManager'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'ContentDeliveryAllowed'; Value = 0 }
	[PSCustomObject]@{ Section = 'ContentDeliveryManager'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'RotatingLockScreenEnabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'ContentDeliveryManager'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'ContentDeliveryManager'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-310093Enabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'ContentDeliveryManager'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338388Enabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'ContentDeliveryManager'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338389Enabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'ContentDeliveryManager'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353694Enabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'ContentDeliveryManager'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SystemPaneSuggestionsEnabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'ContentDeliveryManager'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338393Enabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'SearchHistory'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'AllowSearchToUseLocation'; Value = 0 }
	[PSCustomObject]@{ Section = 'SearchHistory'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'BingSearchEnabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'SearchHistory'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'CortanaConsent'; Value = 0 }
	[PSCustomObject]@{ Section = 'SearchHistory'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name = 'IsDeviceSearchHistoryEnabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'SearchHighlightsPolicy'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'EnableDynamicContentInWSB'; Value = 0 }
	[PSCustomObject]@{ Section = 'Spotlight'; Path = 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsSpotlightFeatures'; Value = 1 }
	[PSCustomObject]@{ Section = 'GameBar'; Path = 'HKCU:\SOFTWARE\Microsoft\GameBar'; Name = 'ShowStartupPanel'; Value = 0 }
	[PSCustomObject]@{ Section = 'SuggestWays'; Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; Name = 'ScoobeSystemSettingEnabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'Copilot'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1 }
	[PSCustomObject]@{ Section = 'Copilot'; Path = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1 }
	[PSCustomObject]@{ Section = 'Copilot'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowCopilotButton'; Value = 0 }
	[PSCustomObject]@{ Section = 'StartRecommendations'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_IrisRecommendations'; Value = 0 }
	[PSCustomObject]@{ Section = 'AdvertisingID'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Value = 0 }
	[PSCustomObject]@{ Section = 'LanguageList'; Path = 'HKCU:\Control Panel\International\User Profile'; Name = 'HttpAcceptLanguageOptOut'; Value = 1 }
	[PSCustomObject]@{ Section = 'AppLaunchTracking'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_TrackProgs'; Value = 0 }
)

# Read the current state of everything this script changes, used by both -Backup and -Preview
if ($Backup -or $Preview) {
	$snapshotTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
	$snapshotRows = @()

	foreach ($setting in $managedSettings) {
		$keyExisted = Test-Path -LiteralPath $setting.Path
		$valueExisted = $false
		$currentValue = $null
		$valueKind = 'DWord'

		if ($keyExisted) {
			$currentItem = Get-ItemProperty -LiteralPath $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue
			if ($null -ne $currentItem) {
				$valueExisted = $true
				$currentValue = $currentItem.($setting.Name)
				$valueKind = (Get-Item -LiteralPath $setting.Path).GetValueKind($setting.Name).ToString()
			}
		}

		$snapshotRows += [PSCustomObject]@{
			ComputerName = $env:COMPUTERNAME
			Timestamp    = $snapshotTimestamp
			Section      = $setting.Section
			Kind         = 'Registry'
			Target       = $setting.Path
			Name         = $setting.Name
			ValueKind    = $valueKind
			Value        = $currentValue
			Existed      = $valueExisted
			KeyExisted   = $keyExisted
		}
	}

	# For the service row, ValueKind holds the current status (Running/Stopped) and Value holds the startup type
	$diagService = Get-Service -Name 'DiagTrack' -ErrorAction SilentlyContinue
	$diagStartType = ''
	$diagStatus = ''
	if ($diagService) {
		$diagStartType = $diagService.StartType.ToString()
		$diagStatus = $diagService.Status.ToString()
	}
	$snapshotRows += [PSCustomObject]@{
		ComputerName = $env:COMPUTERNAME
		Timestamp    = $snapshotTimestamp
		Section      = 'DiagTrack'
		Kind         = 'Service'
		Target       = 'DiagTrack'
		Name         = 'StartType'
		ValueKind    = $diagStatus
		Value        = $diagStartType
		Existed      = [bool]$diagService
		KeyExisted   = ''
	}

	# For task rows, Target holds the task folder, Name the task name, and Value its current state
	foreach ($ceipTask in @(Get-ScheduledTask -TaskPath $ceipPath -ErrorAction SilentlyContinue)) {
		$snapshotRows += [PSCustomObject]@{
			ComputerName = $env:COMPUTERNAME
			Timestamp    = $snapshotTimestamp
			Section      = 'CEIP'
			Kind         = 'Task'
			Target       = $ceipTask.TaskPath
			Name         = $ceipTask.TaskName
			ValueKind    = ''
			Value        = $ceipTask.State.ToString()
			Existed      = $true
			KeyExisted   = ''
		}
	}
}

if ($Backup) {
	try {
		$snapshotRows | Export-Csv -LiteralPath $Backup -NoTypeInformation -Force -ErrorAction Stop
		$backupLine = "Backup saved to: $Backup"
		if (-not $NoConsoleOutput) { Write-Host "`n$backupLine" -ForegroundColor Green }
		$FileOutputLines += $backupLine
	}
	catch {
		# A failed backup stops the run before anything is changed (unconditional console error, like flag validation), since continuing without the requested safety net would defeat its purpose
		Write-Host ""
		Write-Error "Could not save backup to '$Backup': $($_.Exception.Message)"
		exit 1
	}
}

if ($Restore) {
	if (-not $NoConsoleOutput) { Write-Host "`nRestoring settings from '$Restore'..." -ForegroundColor Cyan }

	$backupData = @(Import-Csv -LiteralPath $Restore)
	$restoredCount = 0

	if ($backupData.Count -gt 0 -and $backupData[0].ComputerName -and $backupData[0].ComputerName -ne $env:COMPUTERNAME) {
		$mismatchLine = "This backup was captured on '$($backupData[0].ComputerName)', not the current machine '$env:COMPUTERNAME'. Continuing anyway."
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning $mismatchLine
		}
		$FileOutputLines += $mismatchLine
	}

	foreach ($row in $backupData) {
		if ($excludedSections -contains $row.Section) { continue }

		try {
			if ($row.Kind -eq 'Registry') {
				if ($row.Existed -eq 'True') {
					if ($row.ValueKind -notin @('DWord', 'String')) {
						throw "unsupported value kind '$($row.ValueKind)'"
					}
					if (-not (Test-Path -LiteralPath $row.Target)) { New-Item -Path $row.Target -Force -ErrorAction Stop | Out-Null }
					$restoreValue = if ($row.ValueKind -eq 'DWord') { [int]$row.Value } else { $row.Value }
					Set-ItemProperty -LiteralPath $row.Target -Name $row.Name -Type $row.ValueKind -Value $restoreValue -Force -ErrorAction Stop
				}
				else {
					Remove-ItemProperty -LiteralPath $row.Target -Name $row.Name -ErrorAction SilentlyContinue

					# A key this script created is removed again once it's empty
					if ($row.KeyExisted -eq 'False' -and (Test-Path -LiteralPath $row.Target)) {
						$remainingKey = Get-Item -LiteralPath $row.Target
						if ($remainingKey.ValueCount -eq 0 -and $remainingKey.SubKeyCount -eq 0) {
							Remove-Item -LiteralPath $row.Target -Force -ErrorAction Stop
						}
					}
				}
			}
			elseif ($row.Kind -eq 'Service') {
				if ($row.Value) {
					Set-Service -Name $row.Target -StartupType $row.Value -ErrorAction Stop
					if ($row.ValueKind -eq 'Running') { Start-Service -Name $row.Target -ErrorAction Stop }
				}
			}
			elseif ($row.Kind -eq 'Task') {
				if ($row.Value -ne 'Disabled') {
					Enable-ScheduledTask -TaskPath $row.Target -TaskName $row.Name -ErrorAction Stop | Out-Null
				}
			}
			$restoredCount++
		}
		catch {
			$restoreError = "Could not restore $($row.Section) '$($row.Name)': $($_.Exception.Message)"
			if (-not $NoConsoleOutput) {
				Write-Host ""
				Write-Warning $restoreError
			}
			$FileOutputLines += $restoreError
			$hadErrors = $true
		}
	}

	if ($hadErrors) {
		$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Restore completed with errors - $restoredCount item(s) restored."
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Error $summaryLine
		}
	}
	else {
		$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Restore complete - $restoredCount item(s) restored. A removed Copilot package is not restored by this script."
		if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }
	}
	$FileOutputLines += $summaryLine

	if ($SaveResults) {
		try {
			$outputString = ($FileOutputLines -join "`n") + "`n"
			[System.IO.File]::AppendAllText($SaveResults, $outputString)
			if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green }
		}
		catch {
			# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}

	if ($hadErrors) {
		exit 1
	}

	exit 0
}

if ($Preview) {
	$wouldChangeCount = 0
	$alreadySetCount = 0

	foreach ($sectionName in $validSections) {
		if ($excludedSections -contains $sectionName) { continue }
		if (-not $NoConsoleOutput) { Write-Host "`n$sectionName`:" -ForegroundColor Cyan }

		foreach ($row in @($snapshotRows | Where-Object { $_.Section -eq $sectionName })) {
			if ($row.Kind -eq 'Registry') {
				$proposedValue = ($managedSettings | Where-Object { $_.Path -eq $row.Target -and $_.Name -eq $row.Name }).Value
				if ($row.Existed -and $row.Value -eq $proposedValue) {
					$previewLine = "  $($row.Name): already set ($($row.Value))"
					$alreadySetCount++
				}
				else {
					$currentDisplay = if ($row.Existed) { $row.Value } else { '(not set)' }
					$previewLine = "  $($row.Name): would change from $currentDisplay to $proposedValue"
					$wouldChangeCount++
				}
			}
			elseif ($row.Kind -eq 'Service') {
				if (-not $row.Existed) {
					$previewLine = "  DiagTrack: service not found"
				}
				elseif ($row.Value -eq 'Disabled' -and $row.ValueKind -eq 'Stopped') {
					$previewLine = "  DiagTrack: already disabled and stopped"
					$alreadySetCount++
				}
				else {
					$previewLine = "  DiagTrack: StartType $($row.Value), Status $($row.ValueKind) - would be disabled and stopped"
					$wouldChangeCount++
				}
			}
			elseif ($row.Kind -eq 'Task') {
				if ($row.Value -eq 'Disabled') {
					$previewLine = "  $($row.Name): already disabled"
					$alreadySetCount++
				}
				else {
					$previewLine = "  $($row.Name): $($row.Value) - would be disabled"
					$wouldChangeCount++
				}
			}

			if (-not $NoConsoleOutput) { Write-Host $previewLine }
		}

		if ($sectionName -eq 'Copilot') {
			$previewCopilotCount = @(Get-AppxPackage -Name '*Copilot*').Count
			if ($previewCopilotCount -gt 0) {
				$previewLine = "  Copilot package: $previewCopilotCount found - would be removed for current user"
				$wouldChangeCount++
			}
			else {
				$previewLine = "  Copilot package: none found for current user"
			}
			if (-not $NoConsoleOutput) { Write-Host $previewLine }
		}
	}

	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Preview complete. $wouldChangeCount item(s) would change, $alreadySetCount already set. No changes were made."
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Yellow }
	$FileOutputLines += $summaryLine

	if ($SaveResults) {
		try {
			$outputString = ($FileOutputLines -join "`n") + "`n"
			[System.IO.File]::AppendAllText($SaveResults, $outputString)
			if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green }
		}
		catch {
			# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}

	exit 0
}

# Disable the DiagTrack service (Connected User Experiences and Telemetry)
if ($excludedSections -notcontains 'DiagTrack') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling DiagTrack (Connected User Experiences and Telemetry) service..." -ForegroundColor Cyan }
	try {
		# The startup type is set first so the service stays disabled even if stopping it fails
		Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction Stop
		Stop-Service -Name "DiagTrack" -Force -ErrorAction Stop
		if (-not $NoConsoleOutput) { Write-Host "DiagTrack service disabled." -ForegroundColor Green }
		$FileOutputLines += "DiagTrack service disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "DiagTrack service section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "DiagTrack service section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Disable Sync Provider Notifications
if ($excludedSections -notcontains 'SyncProviderNotifications') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling Sync Provider Notifications..." -ForegroundColor Cyan }
	try {
		$explorerAdvancedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
		Set-ItemProperty -Path $explorerAdvancedPath -Name "ShowSyncProviderNotifications" -Type DWord -Value 0 -Force -ErrorAction Stop
		if (-not $NoConsoleOutput) { Write-Host "Sync Provider Notifications disabled." -ForegroundColor Green }
		$FileOutputLines += "Sync Provider Notifications disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Sync Provider Notifications section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "Sync Provider Notifications section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Disable Widgets (Weather icon on Taskbar, etc.)
if ($excludedSections -notcontains 'Widgets') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling Widgets..." -ForegroundColor Cyan }
	try {
		$dshPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
		if (-not (Test-Path $dshPath)) { New-Item -Path $dshPath -Force -ErrorAction Stop | Out-Null }
		New-ItemProperty -Path $dshPath -Name "AllowWidgets" -Type DWord -Value 0 -Force -ErrorAction Stop | Out-Null
		New-ItemProperty -Path $dshPath -Name "AllowNewsAndInterests" -Type DWord -Value 0 -Force -ErrorAction Stop | Out-Null
		if (-not $NoConsoleOutput) { Write-Host "Widgets disabled." -ForegroundColor Green }
		$FileOutputLines += "Widgets disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Widgets section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "Widgets section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Disable Search Highlights and Bing search ads/web search integration in the Windows 11 Search box
if ($excludedSections -notcontains 'SearchHighlightsBing') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling Search Highlights and Bing Web Search Integration..." -ForegroundColor Cyan }
	try {
		$explorerPolicyPath = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
		if (-not (Test-Path $explorerPolicyPath)) { New-Item -Path $explorerPolicyPath -Force -ErrorAction Stop | Out-Null }
		Set-ItemProperty -Path $explorerPolicyPath -Name "DisableSearchBoxSuggestions" -Type DWord -Value 1 -Force -ErrorAction Stop

		$searchSettingsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'
		Set-ItemProperty -Path $searchSettingsPath -Name "IsDynamicSearchBoxEnabled" -Type DWord -Value 0 -Force -ErrorAction Stop
		Set-ItemProperty -Path $searchSettingsPath -Name "IsCloudSearchEnabled" -Type DWord -Value 0 -Force -ErrorAction Stop
		Set-ItemProperty -Path $searchSettingsPath -Name "IsMSACloudSearchEnabled" -Type DWord -Value 0 -Force -ErrorAction Stop

		if (-not $NoConsoleOutput) { Write-Host "Search Highlights and Bing Web Search Integration disabled." -ForegroundColor Green }
		$FileOutputLines += "Search Highlights and Bing Web Search Integration disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Search Highlights and Bing Web Search Integration section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "Search Highlights and Bing Web Search Integration section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Disable Content Delivery Manager suggestions: promoted silent app installs, advertisements, Spotlight
# tips and suggestions, app suggestions in the Start Menu, Settings app suggestions, etc.
if ($excludedSections -notcontains 'ContentDeliveryManager') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling Content Delivery Manager suggestions..." -ForegroundColor Cyan }
	try {
		$contentDeliveryManagerPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
		if (-not (Test-Path $contentDeliveryManagerPath)) { New-Item -Path $contentDeliveryManagerPath -Force -ErrorAction Stop | Out-Null }
		Set-ItemProperty -Path $contentDeliveryManagerPath -Name "ContentDeliveryAllowed" -Type DWord -Value 0 -Force -ErrorAction Stop
		Set-ItemProperty -Path $contentDeliveryManagerPath -Name "RotatingLockScreenEnabled" -Type DWord -Value 0 -Force -ErrorAction Stop
		Set-ItemProperty -Path $contentDeliveryManagerPath -Name "SilentInstalledAppsEnabled" -Type DWord -Value 0 -Force -ErrorAction Stop
		Set-ItemProperty -Path $contentDeliveryManagerPath -Name "SubscribedContent-310093Enabled" -Type DWord -Value 0 -Force -ErrorAction Stop
		Set-ItemProperty -Path $contentDeliveryManagerPath -Name "SubscribedContent-338388Enabled" -Type DWord -Value 0 -Force -ErrorAction Stop
		Set-ItemProperty -Path $contentDeliveryManagerPath -Name "SubscribedContent-338389Enabled" -Type DWord -Value 0 -Force -ErrorAction Stop
		Set-ItemProperty -Path $contentDeliveryManagerPath -Name "SubscribedContent-353694Enabled" -Type DWord -Value 0 -Force -ErrorAction Stop
		Set-ItemProperty -Path $contentDeliveryManagerPath -Name "SystemPaneSuggestionsEnabled" -Type DWord -Value 0 -Force -ErrorAction Stop
		Set-ItemProperty -Path $contentDeliveryManagerPath -Name "SubscribedContent-338393Enabled" -Type DWord -Value 0 -Force -ErrorAction Stop

		if (-not $NoConsoleOutput) { Write-Host "Content Delivery Manager suggestions disabled." -ForegroundColor Green }
		$FileOutputLines += "Content Delivery Manager suggestions disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Content Delivery Manager suggestions section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "Content Delivery Manager suggestions section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Disable search history and cloud content suggestions
if ($excludedSections -notcontains 'SearchHistory') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling search history and cloud content suggestions..." -ForegroundColor Cyan }
	try {
		$searchPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
		Set-ItemProperty -Path $searchPath -Name "AllowSearchToUseLocation" -Type DWord -Value 0 -Force -ErrorAction Stop
		Set-ItemProperty -Path $searchPath -Name "BingSearchEnabled" -Type DWord -Value 0 -Force -ErrorAction Stop
		Set-ItemProperty -Path $searchPath -Name "CortanaConsent" -Type DWord -Value 0 -Force -ErrorAction Stop

		$searchSettingsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'
		Set-ItemProperty -Path $searchSettingsPath -Name "IsDeviceSearchHistoryEnabled" -Type DWord -Value 0 -Force -ErrorAction Stop

		if (-not $NoConsoleOutput) { Write-Host "Search history and cloud content suggestions disabled." -ForegroundColor Green }
		$FileOutputLines += "Search history and cloud content suggestions disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Search history and cloud content suggestions section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "Search history and cloud content suggestions section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Disable Search Highlights (policy)
if ($excludedSections -notcontains 'SearchHighlightsPolicy') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling Search Highlights (policy)..." -ForegroundColor Cyan }
	try {
		$windowsSearchPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
		if (-not (Test-Path $windowsSearchPolicyPath)) { New-Item -Path $windowsSearchPolicyPath -Force -ErrorAction Stop | Out-Null }
		New-ItemProperty -Path $windowsSearchPolicyPath -Name "EnableDynamicContentInWSB" -Type DWord -Value 0 -Force -ErrorAction Stop | Out-Null
		if (-not $NoConsoleOutput) { Write-Host "Search Highlights (policy) disabled." -ForegroundColor Green }
		$FileOutputLines += "Search Highlights (policy) disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Search Highlights (policy) section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "Search Highlights (policy) section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Disable all Windows Spotlight features
if ($excludedSections -notcontains 'Spotlight') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling Windows Spotlight features..." -ForegroundColor Cyan }
	try {
		$cloudContentPath = 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent'
		if (-not (Test-Path $cloudContentPath)) { New-Item -Path $cloudContentPath -Force -ErrorAction Stop | Out-Null }
		New-ItemProperty -Path $cloudContentPath -Name "DisableWindowsSpotlightFeatures" -Type DWord -Value 1 -Force -ErrorAction Stop | Out-Null
		if (-not $NoConsoleOutput) { Write-Host "Windows Spotlight features disabled." -ForegroundColor Green }
		$FileOutputLines += "Windows Spotlight features disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Windows Spotlight features section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "Windows Spotlight features section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Disable Game Bar Tips
if ($excludedSections -notcontains 'GameBar') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling Game Bar Tips..." -ForegroundColor Cyan }
	try {
		$gameBarPath = 'HKCU:\SOFTWARE\Microsoft\GameBar'
		if (-not (Test-Path $gameBarPath)) { New-Item -Path $gameBarPath -Force -ErrorAction Stop | Out-Null }
		New-ItemProperty -Path $gameBarPath -Name "ShowStartupPanel" -Type DWord -Value 0 -Force -ErrorAction Stop | Out-Null
		if (-not $NoConsoleOutput) { Write-Host "Game Bar Tips disabled." -ForegroundColor Green }
		$FileOutputLines += "Game Bar Tips disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Game Bar Tips section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "Game Bar Tips section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Disable "Suggest ways to get the most out of Windows..."
if ($excludedSections -notcontains 'SuggestWays') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling `"Suggest ways to get the most out of Windows`"..." -ForegroundColor Cyan }
	try {
		$userProfileEngagementPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement'
		if (-not (Test-Path $userProfileEngagementPath)) { New-Item -Path $userProfileEngagementPath -Force -ErrorAction Stop | Out-Null }
		New-ItemProperty -Path $userProfileEngagementPath -Name "ScoobeSystemSettingEnabled" -Type DWord -Value 0 -Force -ErrorAction Stop | Out-Null
		if (-not $NoConsoleOutput) { Write-Host "`"Suggest ways to get the most out of Windows`" disabled." -ForegroundColor Green }
		$FileOutputLines += "`"Suggest ways to get the most out of Windows`" disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "`"Suggest ways to get the most out of Windows`" section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "`"Suggest ways to get the most out of Windows`" section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Disable Windows Copilot
if ($excludedSections -notcontains 'Copilot') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling Windows Copilot..." -ForegroundColor Cyan }
	try {
		$copilotPaths = @(
			'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot',
			'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'
		)

		foreach ($path in $copilotPaths) {
			if (-not (Test-Path $path)) { New-Item -Path $path -Force -ErrorAction Stop | Out-Null }
			New-ItemProperty -Path $path -Name "TurnOffWindowsCopilot" -Type DWord -Value 1 -Force -ErrorAction Stop | Out-Null
		}

		# Disable Copilot button and shortcut
		$explorerAdvancedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
		New-ItemProperty -Path $explorerAdvancedPath -Name "ShowCopilotButton" -Type DWord -Value 0 -Force -ErrorAction Stop | Out-Null

		# Remove Windows Copilot package for current user
		$copilotPackages = @(Get-AppxPackage -Name '*Copilot*')
		if ($copilotPackages.Count -gt 0) {
			foreach ($copilotPackage in $copilotPackages) {
				Remove-AppxPackage -Package $copilotPackage.PackageFullName -ErrorAction Stop
			}
			if (-not $NoConsoleOutput) { Write-Host "Copilot package(s) removed for current user." -ForegroundColor Green }
			$FileOutputLines += "Copilot package(s) removed for current user."
		}
		else {
			if (-not $NoConsoleOutput) { Write-Host "No Copilot package found for current user." -ForegroundColor Green }
			$FileOutputLines += "No Copilot package found for current user."
		}

		if (-not $NoConsoleOutput) { Write-Host "Windows Copilot disabled." -ForegroundColor Green }
		$FileOutputLines += "Windows Copilot disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Windows Copilot section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "Windows Copilot section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Disable recommendations in the Start Menu
if ($excludedSections -notcontains 'StartRecommendations') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling Start Menu recommendations..." -ForegroundColor Cyan }
	try {
		$explorerAdvancedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
		New-ItemProperty -Path $explorerAdvancedPath -Name "Start_IrisRecommendations" -Type DWord -Value 0 -Force -ErrorAction Stop | Out-Null
		if (-not $NoConsoleOutput) { Write-Host "Start Menu recommendations disabled." -ForegroundColor Green }
		$FileOutputLines += "Start Menu recommendations disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Start Menu recommendations section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "Start Menu recommendations section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Privacy & security -> General: disable "Let apps show me personalized ads by using my advertising ID"
if ($excludedSections -notcontains 'AdvertisingID') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling personalized advertising ID..." -ForegroundColor Cyan }
	try {
		$advertisingInfoPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
		if (-not (Test-Path $advertisingInfoPath)) { New-Item -Path $advertisingInfoPath -Force -ErrorAction Stop | Out-Null }
		Set-ItemProperty -Path $advertisingInfoPath -Name "Enabled" -Type DWord -Value 0 -Force -ErrorAction Stop
		if (-not $NoConsoleOutput) { Write-Host "Personalized advertising ID disabled." -ForegroundColor Green }
		$FileOutputLines += "Personalized advertising ID disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Personalized advertising ID section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "Personalized advertising ID section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Disable "Let websites show me locally relevant content by accessing my language list"
if ($excludedSections -notcontains 'LanguageList') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling locally relevant website content via language list..." -ForegroundColor Cyan }
	try {
		$userProfilePath = 'HKCU:\Control Panel\International\User Profile'
		Set-ItemProperty -Path $userProfilePath -Name "HttpAcceptLanguageOptOut" -Type DWord -Value 1 -Force -ErrorAction Stop
		if (-not $NoConsoleOutput) { Write-Host "Locally relevant website content via language list disabled." -ForegroundColor Green }
		$FileOutputLines += "Locally relevant website content via language list disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Locally relevant website content via language list section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "Locally relevant website content via language list section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Disable "Let Windows improve Start and search results by tracking app launches"
if ($excludedSections -notcontains 'AppLaunchTracking') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling app launch tracking for Start and search results..." -ForegroundColor Cyan }
	try {
		$explorerAdvancedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
		Set-ItemProperty -Path $explorerAdvancedPath -Name "Start_TrackProgs" -Type DWord -Value 0 -Force -ErrorAction Stop
		if (-not $NoConsoleOutput) { Write-Host "App launch tracking for Start and search results disabled." -ForegroundColor Green }
		$FileOutputLines += "App launch tracking for Start and search results disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "App launch tracking for Start and search results section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "App launch tracking for Start and search results section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Disable all Customer Experience Improvement Program (CEIP) Scheduled Tasks
if ($excludedSections -notcontains 'CEIP') {
	if (-not $NoConsoleOutput) { Write-Host "`nDisabling Customer Experience Improvement Program (CEIP) scheduled tasks..." -ForegroundColor Cyan }
	try {
		Get-ScheduledTask -TaskPath $ceipPath -ErrorAction SilentlyContinue |
			Where-Object State -ne 'Disabled' |
			Disable-ScheduledTask -ErrorAction Stop | Out-Null
		if (-not $NoConsoleOutput) { Write-Host "Customer Experience Improvement Program (CEIP) scheduled tasks disabled." -ForegroundColor Green }
		$FileOutputLines += "Customer Experience Improvement Program (CEIP) scheduled tasks disabled."
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Customer Experience Improvement Program (CEIP) scheduled tasks section failed: $($_.Exception.Message)"
		}
		$FileOutputLines += "Customer Experience Improvement Program (CEIP) scheduled tasks section failed: $($_.Exception.Message)"
		$hadErrors = $true
	}
}

# Summary
if ($hadErrors) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Telemetry and ads settings disabled with errors - some settings may not have taken effect. Please restart File Explorer or sign out and back in for the applied changes to take effect."
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Error $summaryLine
	}
}
else {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Telemetry and ads settings disabled successfully. Please restart File Explorer or sign out and back in for these changes to take effect."
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }
}
$FileOutputLines += ""
$FileOutputLines += $summaryLine

# Save results to text file if requested
if ($SaveResults) {
	try {
		$outputString = ($FileOutputLines -join "`n") + "`n"
		[System.IO.File]::AppendAllText($SaveResults, $outputString)
		if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green }
	}
	catch {
		# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

if ($hadErrors) {
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.