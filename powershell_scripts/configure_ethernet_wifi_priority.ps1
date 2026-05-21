# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script sets Ethernet adapters to interface metric 10 (highest priority) and Wi-Fi adapters to interface metric 20 (second priority)

# NOTE: Virtual adapters (VMware, VirtualBox, Hyper-V, etc.) are automatically excluded

# NOTE2: Use -RestoreDefaults to re-enable automatic metric for all affected adapters

# Optional flags:
#     -Preview: Show what would be changed without making any changes
#     -RestoreDefaults: Restore automatic metric for all affected adapters
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Preview,
	[switch]$RestoreDefaults,
	[string]$SaveResults,
	[switch]$Help
)

$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Preview] [-RestoreDefaults] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Preview             Show what would be changed without making any changes" -ForegroundColor Cyan
	Write-Host "  -RestoreDefaults     Restore automatic metric for all affected adapters" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
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

$FileOutputLines = @()
$changedCount = 0

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
	'Teredo'
)

Write-Host "`nDetecting network adapters..." -ForegroundColor Cyan
if ($SaveResults) { $FileOutputLines += "Detecting network adapters..." }

# Get all non-virtual physical adapters
$adapters = Get-NetAdapter | Where-Object {
	$adapter = $_
	$adapter.Virtual -eq $false -and
	($virtualPatterns | Where-Object { $adapter.InterfaceDescription -like "*$_*" } | Measure-Object).Count -eq 0
}

# Separate into Ethernet and Wi-Fi
$ethernetAdapters = $adapters | Where-Object {
	$_.InterfaceDescription -notmatch 'Wi-Fi|Wireless|802\.11|WLAN'
}

$wifiAdapters = $adapters | Where-Object {
	$_.InterfaceDescription -match 'Wi-Fi|Wireless|802\.11|WLAN'
}

if (-not $ethernetAdapters -and -not $wifiAdapters) {
	Write-Host "`nNo physical Ethernet or Wi-Fi adapters found." -ForegroundColor Yellow
	exit 0
}

if (-not $ethernetAdapters) {
	Write-Host "`nNo Ethernet adapters found, skipping." -ForegroundColor Yellow
	if ($SaveResults) { $FileOutputLines += "No Ethernet adapters found, skipping." }
}

if ($ethernetAdapters) {
	Write-Host "`nEthernet adapter(s) found:" -ForegroundColor Cyan
	if ($SaveResults) { $FileOutputLines += "`nEthernet adapter(s) found:" }
	foreach ($adapter in $ethernetAdapters) {
		$currentMetric = (Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).InterfaceMetric
		$currentAuto = (Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).AutomaticMetric

		if ($RestoreDefaults) {
			$action = "Restore automatic metric"
		} else {
			$action = "Set interface metric to 10"
		}

		Write-Host "  $($adapter.Name) ($($adapter.InterfaceDescription))"
		Write-Host "       Current metric  : $(if ($currentAuto -eq 'Enabled') { 'Automatic' } else { $currentMetric })"
		Write-Host "       Action          : $action"
		if ($SaveResults) {
			$FileOutputLines += "  $($adapter.Name) ($($adapter.InterfaceDescription))"
			$FileOutputLines += "       Current metric  : $(if ($currentAuto -eq 'Enabled') { 'Automatic' } else { $currentMetric })"
			$FileOutputLines += "       Action          : $action"
		}

		if (-not $Preview) {
			try {
				if ($RestoreDefaults) {
					Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -AutomaticMetric Enabled -ErrorAction Stop
					Write-Host "       Result          : Automatic metric restored" -ForegroundColor Green
					if ($SaveResults) { $FileOutputLines += "       Result          : Automatic metric restored" }
				} else {
					Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -AutomaticMetric Disabled -InterfaceMetric 10 -ErrorAction Stop
					Write-Host "       Result          : Interface metric set to 10" -ForegroundColor Green
					if ($SaveResults) { $FileOutputLines += "       Result          : Interface metric set to 10" }
				}
				$changedCount++
			} catch {
				Write-Host ""
				Write-Warning "Could not configure $($adapter.Name): $($_.Exception.Message)"
			}
		} else {
			$changedCount++
		}
	}
}

if (-not $wifiAdapters) {
	Write-Host "`nNo Wi-Fi adapters found, skipping." -ForegroundColor Yellow
	if ($SaveResults) { $FileOutputLines += "No Wi-Fi adapters found, skipping." }
}

if ($wifiAdapters) {
	Write-Host "`nWi-Fi adapter(s) found:" -ForegroundColor Cyan
	if ($SaveResults) { $FileOutputLines += "`nWi-Fi adapter(s) found:" }
	foreach ($adapter in $wifiAdapters) {
		$currentMetric = (Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).InterfaceMetric
		$currentAuto = (Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).AutomaticMetric

		if ($RestoreDefaults) {
			$action = "Restore automatic metric"
		} else {
			$action = "Set interface metric to 20"
		}

		Write-Host "  $($adapter.Name) ($($adapter.InterfaceDescription))"
		Write-Host "       Current metric  : $(if ($currentAuto -eq 'Enabled') { 'Automatic' } else { $currentMetric })"
		Write-Host "       Action          : $action"
		if ($SaveResults) {
			$FileOutputLines += "  $($adapter.Name) ($($adapter.InterfaceDescription))"
			$FileOutputLines += "       Current metric  : $(if ($currentAuto -eq 'Enabled') { 'Automatic' } else { $currentMetric })"
			$FileOutputLines += "       Action          : $action"
		}

		if (-not $Preview) {
			try {
				if ($RestoreDefaults) {
					Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -AutomaticMetric Enabled -ErrorAction Stop
					Write-Host "       Result          : Automatic metric restored" -ForegroundColor Green
					if ($SaveResults) { $FileOutputLines += "       Result          : Automatic metric restored" }
				} else {
					Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -AutomaticMetric Disabled -InterfaceMetric 20 -ErrorAction Stop
					Write-Host "       Result          : Interface metric set to 20" -ForegroundColor Green
					if ($SaveResults) { $FileOutputLines += "       Result          : Interface metric set to 20" }
				}
				$changedCount++
			} catch {
				Write-Host ""
				Write-Warning "Could not configure $($adapter.Name): $($_.Exception.Message)"
			}
		} else {
			$changedCount++
		}
	}
}

Write-Host ""
Write-Host "========================================" 
if ($SaveResults) { $FileOutputLines += "========================================" }

if ($Preview) {
	$summaryLine = "$ScriptName`: Preview complete. $changedCount adapter(s) would be configured."
	Write-Host $summaryLine -ForegroundColor Cyan
} elseif ($RestoreDefaults) {
	$summaryLine = "$ScriptName`: Automatic metric restored for $changedCount adapter(s)."
	Write-Host $summaryLine -ForegroundColor Green
} else {
	$summaryLine = "$ScriptName`: $changedCount adapter(s) configured successfully."
	Write-Host $summaryLine -ForegroundColor Green
}

if ($SaveResults) {
	$FileOutputLines += $summaryLine

	while ($FileOutputLines[-1] -eq '') {
		$FileOutputLines = $FileOutputLines[0..($FileOutputLines.Count - 2)]
	}

	try {
		$outputString = ($FileOutputLines -join "`n")
		[System.IO.File]::WriteAllText($SaveResults, $outputString)
		Write-Host "`nResults saved to: $SaveResults" -ForegroundColor Green
	} catch {
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.