# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script stops and disables various unnecessary services I don't use in Windows 11
# I strongly recommend creating a backup of your existing service settings before running this script. This way if something breaks you'll be able to figure out what changed and revert accordingly.
# Instructions:
# 1. Open PowerShell and type the following:
# 2. Get-Service | Select-Object Name, Status, StartType | Out-File -FilePath C:\Users\<username>\Desktop\Service_Status.txt

# NOTE: Substitute <username> with whatever your username is in the above command

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

Write-Host "`nChecking service status..." -ForegroundColor Cyan

$totalProcessed = 0
$totalChanged = 0
$totalAlreadyDisabled = 0

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

foreach ($entry in $services) {
	$name = $entry.Name
	$display = $entry.Display
	$totalProcessed++
	$serviceChanged = $false

	$svc = Get-Service -Name $name -ErrorAction SilentlyContinue

	if (-not $svc) {
		Write-Host "`nService '$name' ($display) not found." -ForegroundColor Yellow
		continue
	}

	# Disable the service
	if ($svc.StartType -eq 'Disabled') {
		Write-Host "`nService '$name' ($display) is already disabled." -ForegroundColor Yellow
		$totalAlreadyDisabled++
	}
	else {
		try {
			Set-Service -Name $name -StartupType Disabled -ErrorAction Stop
			Write-Host "`nService '$name' ($display) startup type successfully set to Disabled." -ForegroundColor Green
			$serviceChanged = $true
		}
		catch {
			Write-Host ""
			Write-Warning "Could not disable service '$name' ($display): $($_.Exception.Message)"
		}
	}

	# Stop the service if it's currently running
	if ($svc.Status -eq 'Stopped') {
		Write-Host "Service '$name' ($display) is already stopped." -ForegroundColor Yellow
	}
	else {
		try {
			Stop-Service -Name $name -Force -ErrorAction Stop
			Write-Host "Service '$name' ($display) stopped successfully." -ForegroundColor Green
			$serviceChanged = $true
		}
		catch {
			Write-Host ""
			Write-Warning "Could not stop service '$name' ($display): $($_.Exception.Message)"
		}
	}

	if ($serviceChanged) { $totalChanged++ }
}

# Summary
$summaryLine = "$ScriptName`: $totalProcessed service(s) processed: $totalChanged changed, $totalAlreadyDisabled already disabled."
Write-Host "`n$summaryLine" -ForegroundColor $(if ($totalChanged -gt 0) { 'Green' } else { 'Yellow' })

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.