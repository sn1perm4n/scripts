# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script sets Ethernet adapters to interface metric 10 (highest priority) and Wi-Fi adapters to interface metric 20 (second priority) by default, which -EthernetMetric and -WifiMetric can change. This means that Ethernet always has top priority over Wi-Fi if both adapters are enabled and Ethernet is connected.

# NOTE: Virtual adapters (VMware, VirtualBox, Hyper-V, etc.) are automatically excluded

# NOTE2: Use -RestoreDefaults to re-enable automatic metric for all affected adapters

# NOTE3: Disabled adapters are skipped — enable the adapter and re-run this script to configure

# NOTE4: Use -IncludeIPv6 to also configure IPv6 interface metrics (skipped silently if IPv6 is disabled on an adapter)

# NOTE5: Adapters are classified by the media type their driver reports (Wi-Fi or wired Ethernet), and only adapters backed by physical or guest-visible hardware are configured, so virtual, Bluetooth, cellular and phone tethering adapters are left alone

# NOTE6: -EthernetMetric and -WifiMetric must be between 1 and 9999, and -EthernetMetric must be lower than -WifiMetric, since a lower metric means higher priority

# Optional flags:
#     -EthernetMetric <N>:   Interface metric to set on Ethernet adapters (default: 10; must be lower than -WifiMetric)
#     -IncludeIPv6:          Also configure IPv6 interface metrics
#     -NoConsoleOutput:      Suppress console output (requires -SaveResults)
#     -Preview:              Show what would be changed without making any changes
#     -RestoreDefaults:      Restore automatic metric for all affected adapters
#     -SaveResults <PATH>:   Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)
#     -WifiMetric <N>:       Interface metric to set on Wi-Fi adapters (default: 20)
#     -Help / -?:            Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[int]$EthernetMetric = 10,
	[switch]$IncludeIPv6,
	[switch]$NoConsoleOutput,
	[switch]$Preview,
	[switch]$RestoreDefaults,
	[string]$SaveResults,
	[int]$WifiMetric = 20,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-EthernetMetric <N>] [-IncludeIPv6] [-NoConsoleOutput] [-Preview] [-RestoreDefaults] [-SaveResults <PATH>] [-WifiMetric <N>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -EthernetMetric <N>  Interface metric to set on Ethernet adapters (default: 10; must be lower than -WifiMetric)" -ForegroundColor Cyan
	Write-Host "  -IncludeIPv6         Also configure IPv6 interface metrics" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Preview             Show what would be changed without making any changes" -ForegroundColor Cyan
	Write-Host "  -RestoreDefaults     Restore automatic metric for all affected adapters" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)" -ForegroundColor Cyan
	Write-Host "  -WifiMetric <N>      Interface metric to set on Wi-Fi adapters (default: 20)" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# Validate -SaveResults path if specified
if ($SaveResults) {
	$saveDir = Split-Path $SaveResults -Parent
	if ($saveDir -and -not (Test-Path $saveDir)) {
		Write-Host ""
		Write-Error "The directory for -SaveResults does not exist: '$saveDir'"
		exit 1
	}
}

# -NoConsoleOutput requires -SaveResults, since without it there's nowhere to record results
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults."
	exit 1
}

# -EthernetMetric and -WifiMetric must be valid interface metrics (1-9999), and Ethernet must be lower than Wi-Fi, since the purpose of this script is to give Ethernet priority
if ($EthernetMetric -lt 1 -or $EthernetMetric -gt 9999 -or $WifiMetric -lt 1 -or $WifiMetric -gt 9999) {
	Write-Host ""
	Write-Error "-EthernetMetric and -WifiMetric must be between 1 and 9999."
	exit 1
}

if ($EthernetMetric -ge $WifiMetric) {
	Write-Host ""
	Write-Error "-EthernetMetric ($EthernetMetric) must be lower than -WifiMetric ($WifiMetric), since a lower metric means higher priority."
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

$FileOutputLines = @()
$changedCount = 0
$alreadyCount = 0
$disabledCount = 0
$failedCount = 0
$exitCode = 0
$hostname = $env:COMPUTERNAME

# Known virtual adapter description patterns to exclude
$virtualPatterns = @(
	'VMware',
	'VirtualBox',
	'Hyper-V',
	'Microsoft Wi-Fi Direct',
	'Microsoft Hosted Network',
	'Bluetooth',
	'Loopback',
	'WAN Miniport',
	'RAS Async Adapter',
	'Teredo',
	# Phone tethering adapters
	'Remote NDIS'
)

if (-not $NoConsoleOutput) {
	Write-Host "`nHostname: $hostname" -ForegroundColor Cyan
	Write-Host "Detecting network adapters..." -ForegroundColor Cyan
}
if ($SaveResults) {
	$FileOutputLines += ""
	$FileOutputLines += "Detecting network adapters..."
}

# Get all non-virtual physical adapters
# HardwareInterface is only true for adapters backed by physical (or guest-visible) hardware, which also excludes host-only and virtual switch adapters whichever vendor made them
$adapters = Get-NetAdapter | Where-Object {
	$adapter = $_
	$adapter.HardwareInterface -eq $true -and
	$adapter.Virtual -eq $false -and
	($virtualPatterns | Where-Object { $adapter.InterfaceDescription -like "*$_*" } | Measure-Object).Count -eq 0
}

# Separate into Ethernet and Wi-Fi
# The media type the driver reports decides: 9 (Native 802.11) or 1 (Wireless LAN) is Wi-Fi and 14 (802.3) is Ethernet, so anything else (i.e. cellular) is left alone
# Some older drivers report 0 (unspecified) instead, so those are treated as Ethernet unless their description looks like Wi-Fi
$wifiPattern = 'Wi-Fi|Wireless|802\.11|WLAN'
$isWifi = {
	param($candidate)
	$candidate.NdisPhysicalMedium -in 9, 1 -or ($candidate.NdisPhysicalMedium -eq 0 -and $candidate.InterfaceDescription -match $wifiPattern)
}

$ethernetAdapters = @($adapters | Where-Object { $_.NdisPhysicalMedium -in 14, 0 -and -not (& $isWifi $_) })
$wifiAdapters = @($adapters | Where-Object { & $isWifi $_ })

if (-not $ethernetAdapters -and -not $wifiAdapters) {
	$warningMessage = "$ScriptName`: No physical Ethernet or Wi-Fi adapters found."
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Warning $warningMessage
	}
	if ($SaveResults) {
		$FileOutputLines += $warningMessage
		try {
			$outputString = ($FileOutputLines -join "`n") + "`n"
			[System.IO.File]::AppendAllText($SaveResults, $outputString)
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}
	exit 0
}

# Each adapter group is configured with its own metric
$adapterGroups = @(
	@{ Label = 'Ethernet'; Adapters = $ethernetAdapters; Metric = $EthernetMetric },
	@{ Label = 'Wi-Fi'; Adapters = $wifiAdapters; Metric = $WifiMetric }
)

# IPv4 is always configured, and IPv6 only with -IncludeIPv6
$addressFamilies = @('IPv4')
if ($IncludeIPv6) {
	$addressFamilies += 'IPv6'
}

foreach ($group in $adapterGroups) {
	$metric = $group.Metric

	if (-not $group.Adapters) {
		if (-not $NoConsoleOutput) { Write-Host "`nNo $($group.Label) adapters found, skipping." -ForegroundColor Yellow }
		if ($SaveResults) { $FileOutputLines += "No $($group.Label) adapters found, skipping." }
		continue
	}

	if (-not $NoConsoleOutput) { Write-Host "`n$($group.Label) adapter(s) found:" -ForegroundColor Cyan }
	if ($SaveResults) { $FileOutputLines += "`n$($group.Label) adapter(s) found:" }

	foreach ($adapter in $group.Adapters) {
		if (-not $NoConsoleOutput) { Write-Host "  $($adapter.Name) ($($adapter.InterfaceDescription))" }
		if ($SaveResults) { $FileOutputLines += "  $($adapter.Name) ($($adapter.InterfaceDescription))" }

		foreach ($family in $addressFamilies) {
			$ipInterface = Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily $family -ErrorAction SilentlyContinue

			# A missing IPv4 interface means the adapter is disabled, while a missing IPv6 interface just means IPv6 is turned off, which is skipped silently
			if (-not $ipInterface) {
				if ($family -eq 'IPv4') {
					$disabledCount++
					if (-not $NoConsoleOutput) { Write-Host "       Result          : Adapter is disabled, skipping. Enable the adapter and re-run this script to configure." -ForegroundColor Yellow }
					if ($SaveResults) { $FileOutputLines += "       Result          : Adapter is disabled, skipping. Enable the adapter and re-run this script to configure." }
					break
				}
				continue
			}

			$currentMetric = $ipInterface.InterfaceMetric
			$currentAuto = $ipInterface.AutomaticMetric

			$alreadyConfigured = (-not $RestoreDefaults -and $currentAuto -eq 'Disabled' -and $currentMetric -eq $metric) -or
				($RestoreDefaults -and $currentAuto -eq 'Enabled')

			if ($RestoreDefaults) {
				$action = "Restore automatic metric"
				$resultText = "Automatic metric restored"
			}
			else {
				$action = "Set interface metric to $metric"
				$resultText = "Interface metric set to $metric"
			}

			$currentDisplay = $currentMetric
			if ($currentAuto -eq 'Enabled') {
				$currentDisplay = 'Automatic'
			}

			if (-not $NoConsoleOutput) { Write-Host "       Current metric  : $currentDisplay ($family)" }
			if ($SaveResults) { $FileOutputLines += "       Current metric  : $currentDisplay ($family)" }

			if ($alreadyConfigured) {
				if (-not $NoConsoleOutput) { Write-Host "       Result          : Already configured, skipping ($family)" -ForegroundColor Yellow }
				if ($SaveResults) { $FileOutputLines += "       Result          : Already configured, skipping ($family)" }
				if ($family -eq 'IPv4') { $alreadyCount++ }
			}
			elseif ($Preview) {
				if (-not $NoConsoleOutput) { Write-Host "       Action          : $action ($family)" }
				if ($SaveResults) { $FileOutputLines += "       Action          : $action ($family)" }
				if ($family -eq 'IPv4') { $changedCount++ }
			}
			else {
				if (-not $NoConsoleOutput) { Write-Host "       Action          : $action ($family)" }
				if ($SaveResults) { $FileOutputLines += "       Action          : $action ($family)" }
				try {
					$setParams = @{
						InterfaceIndex = $adapter.ifIndex
						AddressFamily = $family
						ErrorAction = 'Stop'
					}
					if ($RestoreDefaults) {
						$setParams.AutomaticMetric = 'Enabled'
					}
					else {
						$setParams.AutomaticMetric = 'Disabled'
						$setParams.InterfaceMetric = $metric
					}
					Set-NetIPInterface @setParams

					if (-not $NoConsoleOutput) { Write-Host "       Result          : $resultText ($family)" -ForegroundColor Green }
					if ($SaveResults) { $FileOutputLines += "       Result          : $resultText ($family)" }
					if ($family -eq 'IPv4') { $changedCount++ }
				}
				catch {
					$failedCount++
					if (-not $NoConsoleOutput) {
						Write-Host ""
						Write-Warning "Could not configure $($adapter.Name) $family`: $($_.Exception.Message)"
					}
					if ($SaveResults) { $FileOutputLines += "Could not configure $($adapter.Name) $family`: $($_.Exception.Message)" }
				}
			}
		}
	}
}

if (-not $NoConsoleOutput) { Write-Host "" }
if ($Preview) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Preview complete. $changedCount adapter(s) would be configured."
	if (-not $NoConsoleOutput) { Write-Host $summaryLine -ForegroundColor Cyan }
}
elseif ($failedCount -gt 0) {
	$exitCode = 1
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Finished with errors. $changedCount adapter(s) configured, $failedCount operation(s) failed."
	if (-not $NoConsoleOutput) { Write-Warning $summaryLine }
}
elseif ($changedCount -gt 0 -and $RestoreDefaults) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Automatic metric restored for $changedCount adapter(s)."
	if (-not $NoConsoleOutput) { Write-Host $summaryLine -ForegroundColor Green }
}
elseif ($changedCount -gt 0) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] $changedCount adapter(s) configured successfully."
	if (-not $NoConsoleOutput) { Write-Host $summaryLine -ForegroundColor Green }
}
elseif ($alreadyCount -gt 0) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] All adapters already configured, no changes made."
	if (-not $NoConsoleOutput) { Write-Host $summaryLine -ForegroundColor Cyan }
}
else {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] No adapters were configured because every adapter found is disabled."
	if (-not $NoConsoleOutput) { Write-Host $summaryLine -ForegroundColor Yellow }
}

if ($SaveResults) {
	$FileOutputLines += ""
	$FileOutputLines += $summaryLine

	while ($FileOutputLines.Count -gt 0 -and $FileOutputLines[-1] -eq '') {
		$FileOutputLines = @($FileOutputLines | Select-Object -First ($FileOutputLines.Count - 1))
	}

	try {
		$outputString = ($FileOutputLines -join "`n") + "`n"
		[System.IO.File]::AppendAllText($SaveResults, $outputString)
		if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to: $SaveResults" -ForegroundColor Green }
	}
	catch {
		# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

exit $exitCode

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.