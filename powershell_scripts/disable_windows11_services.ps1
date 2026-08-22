# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script stops and disables various services I don't use in Windows 11

# NOTE: This list was curated for my own machine. Review it against the target machine's actual usage before running, since a service that's safely unnecessary on one machine (i.e. BitLocker, Netlogon, Internet Connection Sharing, Remote Access, Windows Biometric Service) may not be on another.

# NOTE2: -Backup always captures the full service list regardless of -Exclude, so a complete pre-change snapshot exists even for services skipped on this run

# NOTE3: -Restore compares the backup's recorded ComputerName against the current machine and warns (but does not block) on a mismatch, since restoring one machine's service state onto a different machine may not be appropriate

# NOTE4: Get-Service does not distinguish "Automatic (Delayed Start)" from plain "Automatic" in its StartType property, so -Restore may not preserve the delayed-start flag specifically, only the base startup type

# Optional flags:
#     -Backup <PATH>:      Save current service status/startup type to a CSV file before making changes (captures the full list, ignores -Exclude)
#     -Exclude <NAME,...>: Comma-separated service name(s) to skip (i.e. -Exclude "BDESVC,Netlogon")
#     -NoConsoleOutput:    Suppress console output (requires -SaveResults)
#     -Preview:            Report current status/startup type for every service without making any changes
#     -Restore <PATH>:     Restore services to the StartType/Status recorded in a -Backup CSV file (mutually exclusive with -Preview)
#     -SaveResults <PATH>: Save results to a text file (appends if file exists)
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
	Write-Host "  -Backup <PATH>       Save current service status/startup type to a CSV file before making changes (captures the full list, ignores -Exclude)" -ForegroundColor Cyan
	Write-Host "  -Exclude <NAME,...>  Comma-separated service name(s) to skip (i.e. -Exclude ""BDESVC,Netlogon"")" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Preview             Report current status/startup type for every service without making any changes" -ForegroundColor Cyan
	Write-Host "  -Restore <PATH>      Restore services to the StartType/Status recorded in a -Backup CSV file (mutually exclusive with -Preview)" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (appends if file exists)" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# -Preview and -Restore are mutually exclusive
if ($Preview -and $Restore) {
	Write-Host ""
	Write-Error "-Preview and -Restore are mutually exclusive."
	exit 1
}

# -NoConsoleOutput requires -SaveResults, since without it there's nowhere to record results
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults."
	exit 1
}

# Validate save paths if specified
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

# -Restore requires the backup file to already exist, since it's read from rather than written to
if ($Restore -and -not (Test-Path $Restore)) {
	Write-Host ""
	Write-Error "-Restore file not found: '$Restore'"
	exit 1
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

# Parse -Exclude into a normalized list of service names
$excludedNames = @()
if ($Exclude) {
	$excludedNames = $Exclude -split ',' | ForEach-Object { $_.Trim() }
}

$services = @(
	@{ Name = "AssignedAccessManagerSvc"; Display = "AssignedAccessManager Service" },
	@{ Name = "BDESVC";                   Display = "BitLocker Drive Encryption Service" },
	@{ Name = "DiagTrack";                Display = "Connected User Experiences and Telemetry" },
	@{ Name = "dmwappushservice";         Display = "Device Management WAP Push message Routing Service" },
	@{ Name = "WdiServiceHost";           Display = "Diagnostic Service Host" },
	@{ Name = "DialogBlockingService";    Display = "DialogBlockingService" },
	@{ Name = "MapsBroker";               Display = "Downloaded Maps Manager" },
	@{ Name = "lfsvc";                    Display = "Geolocation Service" },
	@{ Name = "SharedAccess";             Display = "Internet Connection Sharing (ICS)" },
	@{ Name = "AppVClient";               Display = "Microsoft App-V Client" },
	@{ Name = "MsKeyboardFilter";         Display = "Microsoft Keyboard Filter" },
	@{ Name = "NetTcpPortSharing";        Display = "Net.Tcp Port Sharing Service" },
	@{ Name = "Netlogon";                 Display = "Netlogon" },
	@{ Name = "CscService";               Display = "Offline Files" },
	@{ Name = "WpcMonSvc";                Display = "Parental Controls" },
	@{ Name = "PhoneSvc";                 Display = "Phone Service" },
	@{ Name = "WPDBusEnum";               Display = "Portable Device Enumerator Service" },
	@{ Name = "RetailDemo";               Display = "Retail Demo Service" },
	@{ Name = "RemoteAccess";             Display = "Routing and Remote Access" },
	@{ Name = "seclogon";                 Display = "Secondary Logon" },
	@{ Name = "SensorService";            Display = "Sensor Service" },
	@{ Name = "shpamsvc";                 Display = "Shared PC Account Manager" },
	@{ Name = "ShellHWDetection";         Display = "Shell Hardware Detection" },
	@{ Name = "UevAgentService";          Display = "User Experience Virtualization Service" },
	@{ Name = "WalletService";            Display = "WalletService" },
	@{ Name = "WbioSrvc";                 Display = "Windows Biometric Service" },
	@{ Name = "wcncsvc";                  Display = "Windows Connect Now - Config Registrar" },
	@{ Name = "WMPNetworkSvc";            Display = "Windows Media Player Network Sharing Service" },
	@{ Name = "icssvc";                   Display = "Windows Mobile Hotspot Service" },
	@{ Name = "XboxGipSvc";               Display = "Xbox Accessory Management Service" },
	@{ Name = "XblAuthManager";           Display = "Xbox Live Auth Manager" },
	@{ Name = "XblGameSave";              Display = "Xbox Live Game Save" },
	@{ Name = "XboxNetApiSvc";            Display = "Xbox Live Networking Service" }
)

# Take a backup snapshot of the full list before making any changes, regardless of mode
if ($Backup) {
	try {
		$backupRows = $services | ForEach-Object {
			$svc = Get-Service -Name $_.Name -ErrorAction SilentlyContinue
			[PSCustomObject]@{
				ComputerName = $env:COMPUTERNAME
				Timestamp    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
				Name         = $_.Name
				DisplayName  = $_.Display
				StartType    = if ($svc) { $svc.StartType } else { 'NotFound' }
				Status       = if ($svc) { $svc.Status } else { 'NotFound' }
			}
		}
		$backupRows | Export-Csv -Path $Backup -NoTypeInformation -Force
		if (-not $NoConsoleOutput) { Write-Host "`nBackup saved to: $Backup" -ForegroundColor Green }
	}
	catch {
		# This warning covers a failure to write to -Backup itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
		Write-Host ""
		Write-Warning "Could not save backup to '$Backup': $($_.Exception.Message)"
	}
}

$resultLines = @()

if ($Restore) {
	# Restore mode
	if (-not $NoConsoleOutput) { Write-Host "`nRestoring services from '$Restore'..." -ForegroundColor Cyan }

	$backupData = Import-Csv -Path $Restore

	if ($backupData -and $backupData[0].ComputerName -and $backupData[0].ComputerName -ne $env:COMPUTERNAME) {
		Write-Host ""
		Write-Warning "This backup was captured on '$($backupData[0].ComputerName)', not the current machine '$env:COMPUTERNAME'. Continuing anyway."
	}

	$totalRestored = 0
	$totalAlreadyCorrect = 0
	$totalNotFound = 0
	$totalExcluded = 0

	foreach ($row in $backupData) {
		if ($excludedNames -contains $row.Name) {
			$totalExcluded++
			continue
		}

		if ($row.StartType -eq 'NotFound') { continue }

		$svc = Get-Service -Name $row.Name -ErrorAction SilentlyContinue
		if (-not $svc) {
			if (-not $NoConsoleOutput) { Write-Host "`nService '$($row.Name)' ($($row.DisplayName)) not found." -ForegroundColor Yellow }
			$totalNotFound++
			continue
		}

		$restoredThis = $false

		if ($svc.StartType -ne $row.StartType) {
			try {
				Set-Service -Name $row.Name -StartupType $row.StartType -ErrorAction Stop
				if (-not $NoConsoleOutput) { Write-Host "`nService '$($row.Name)' ($($row.DisplayName)) startup type restored to $($row.StartType)." -ForegroundColor Green }
				$restoredThis = $true
			}
			catch {
				Write-Host ""
				Write-Warning "Could not restore startup type for '$($row.Name)' ($($row.DisplayName)): $($_.Exception.Message)"
			}
		}

		if ($row.Status -eq 'Running' -and $svc.Status -ne 'Running') {
			try {
				Start-Service -Name $row.Name -ErrorAction Stop
				if (-not $NoConsoleOutput) { Write-Host "Service '$($row.Name)' ($($row.DisplayName)) started." -ForegroundColor Green }
				$restoredThis = $true
			}
			catch {
				Write-Host ""
				Write-Warning "Could not start '$($row.Name)' ($($row.DisplayName)): $($_.Exception.Message)"
			}
		}
		elseif ($row.Status -eq 'Stopped' -and $svc.Status -ne 'Stopped') {
			try {
				Stop-Service -Name $row.Name -Force -ErrorAction Stop
				if (-not $NoConsoleOutput) { Write-Host "Service '$($row.Name)' ($($row.DisplayName)) stopped." -ForegroundColor Green }
				$restoredThis = $true
			}
			catch {
				Write-Host ""
				Write-Warning "Could not stop '$($row.Name)' ($($row.DisplayName)): $($_.Exception.Message)"
			}
		}

		if ($restoredThis) { $totalRestored++ } else { $totalAlreadyCorrect++ }
	}

	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Restore complete: $totalRestored restored, $totalAlreadyCorrect already matched backup, $totalNotFound not found, $totalExcluded excluded."
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }
	$resultLines += $summaryLine
}
elseif ($Preview) {
	# Preview mode
	if (-not $NoConsoleOutput) { Write-Host "`nPreviewing current service status (no changes will be made)..." -ForegroundColor Cyan }

	$totalExcluded = 0

	foreach ($entry in $services) {
		if ($excludedNames -contains $entry.Name) {
			$totalExcluded++
			continue
		}

		$svc = Get-Service -Name $entry.Name -ErrorAction SilentlyContinue
		if (-not $svc) {
			$line = "Service '$($entry.Name)' ($($entry.Display)): NOT FOUND"
		}
		else {
			$line = "Service '$($entry.Name)' ($($entry.Display)): StartType=$($svc.StartType), Status=$($svc.Status)"
		}
		if (-not $NoConsoleOutput) { Write-Host $line }
		$resultLines += $line
	}

	$resultLines += "$ScriptName`: [$env:COMPUTERNAME] Preview complete. No changes were made. $totalExcluded excluded."
}
else {
	# Default mode: disable and stop services
	if (-not $NoConsoleOutput) { Write-Host "`nChecking service status..." -ForegroundColor Cyan }

	$totalProcessed = 0
	$totalChanged = 0
	$totalAlreadyDisabled = 0
	$totalNotFound = 0
	$totalExcluded = 0

	foreach ($entry in $services) {
		if ($excludedNames -contains $entry.Name) {
			$totalExcluded++
			continue
		}

		$name = $entry.Name
		$display = $entry.Display
		$totalProcessed++
		$serviceChanged = $false

		$svc = Get-Service -Name $name -ErrorAction SilentlyContinue

		if (-not $svc) {
			if (-not $NoConsoleOutput) { Write-Host "`nService '$name' ($display) not found." -ForegroundColor Yellow }
			$totalNotFound++
			continue
		}

		# Disable the service
		if ($svc.StartType -eq 'Disabled') {
			if (-not $NoConsoleOutput) { Write-Host "`nService '$name' ($display) is already disabled." -ForegroundColor Yellow }
			$totalAlreadyDisabled++
		}
		else {
			try {
				Set-Service -Name $name -StartupType Disabled -ErrorAction Stop
				if (-not $NoConsoleOutput) { Write-Host "`nService '$name' ($display) startup type successfully set to Disabled." -ForegroundColor Green }
				$serviceChanged = $true
			}
			catch {
				Write-Host ""
				Write-Warning "Could not disable service '$name' ($display): $($_.Exception.Message)"
			}
		}

		# Stop the service if it's currently running
		if ($svc.Status -eq 'Stopped') {
			if (-not $NoConsoleOutput) { Write-Host "Service '$name' ($display) is already stopped." -ForegroundColor Yellow }
		}
		else {
			try {
				Stop-Service -Name $name -Force -ErrorAction Stop
				if (-not $NoConsoleOutput) { Write-Host "Service '$name' ($display) stopped successfully." -ForegroundColor Green }
				$serviceChanged = $true
			}
			catch {
				Write-Host ""
				Write-Warning "Could not stop service '$name' ($display): $($_.Exception.Message)"
			}
		}

		if ($serviceChanged) { $totalChanged++ }
	}

	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] $totalProcessed service(s) processed: $totalChanged changed, $totalAlreadyDisabled already disabled, $totalNotFound not found, $totalExcluded excluded."
	if (-not $NoConsoleOutput) {
		Write-Host "`n$summaryLine" -ForegroundColor $(if ($totalChanged -gt 0) { 'Green' } else { 'Yellow' })
	}
	$resultLines += $summaryLine
}

# Save results
if ($SaveResults) {
	try {
		$content = ($resultLines -join "`n") + "`n"
		[System.IO.File]::AppendAllText($SaveResults, $content)
		if (-not $NoConsoleOutput) { Write-Host "`nResults saved to: $SaveResults" -ForegroundColor Green }
	}
	catch {
		# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.