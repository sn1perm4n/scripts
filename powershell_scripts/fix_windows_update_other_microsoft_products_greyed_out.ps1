# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script removes the Windows Update policy values that grey out "Receive updates for other Microsoft products" in Settings

# NOTE: NoAutoUpdate (under the WindowsUpdate\AU policy key) disables automatic updates and locks the toggle, and AllowMUUpdateService (under either policy key) puts the toggle under policy control. Removing them hands control back to Windows Update, which also turns automatic updates back on.

# NOTE2: Values this script removes (all normally REG_DWORD):
#     HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate (1 = automatic updates disabled)
#     HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\AllowMUUpdateService (1 = updates for other Microsoft products on, 0 = off)
#     HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AllowMUUpdateService (same meaning, placed here by some tools)

# NOTE3: None of these values exist on a stock Windows installation (OEM imaging or management tools add them), so removing them restores the default behavior. To recreate one by hand, note the "Found:" line this script prints, or use -Backup, i.e. in an elevated PowerShell: New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoUpdate' -PropertyType DWord -Value 1

# Optional flags:
#     -Backup <PATH>: Export the Windows Update policy keys to a .reg file before removing anything
#     -DeleteAll:     Remove all found values without prompting
#     -Force:         Continue on a domain-joined or MDM-enrolled PC, where policy may reapply the values
#     -Preview:       List the values that would be removed without changing anything
#     -Help / -?:     Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[string]$Backup,
	[switch]$DeleteAll,
	[switch]$Force,
	[switch]$Preview,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup <PATH>] [-DeleteAll] [-Force] [-Preview] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup <PATH>  Export the Windows Update policy keys to a .reg file before removing anything" -ForegroundColor Cyan
	Write-Host "  -DeleteAll      Remove all found values without prompting" -ForegroundColor Cyan
	Write-Host "  -Force          Continue on a domain-joined or MDM-enrolled PC, where policy may reapply the values" -ForegroundColor Cyan
	Write-Host "  -Preview        List the values that would be removed without changing anything" -ForegroundColor Cyan
	Write-Host "  -Help           Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

$policyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$policyAuKey = "$policyKey\AU"

# Values that grey out the toggle
$targets = @(
	[pscustomobject]@{ Key = $policyAuKey; Name = 'NoAutoUpdate' }
	[pscustomobject]@{ Key = $policyAuKey; Name = 'AllowMUUpdateService' }
	[pscustomobject]@{ Key = $policyKey; Name = 'AllowMUUpdateService' }
)

# -DeleteAll and -Preview are mutually exclusive
if ($DeleteAll -and $Preview) {
	Write-Host ""
	Write-Error "-DeleteAll and -Preview are mutually exclusive."
	exit 1
}

# Validate -Backup path if specified (it needs a file path)
if ($PSBoundParameters.ContainsKey('Backup')) {
	if (-not $Backup) {
		Write-Host ""
		Write-Error "-Backup requires a file path (i.e. -Backup `"C:\Backups\WindowsUpdatePolicy.reg`")."
		exit 1
	}

	$Backup = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Backup)

	if (Test-Path -LiteralPath $Backup -PathType Container) {
		Write-Host ""
		Write-Error "-Backup must be a file path, not a folder: '$Backup'"
		exit 1
	}

	if (-not (Test-Path -LiteralPath (Split-Path $Backup -Parent) -PathType Container)) {
		Write-Host ""
		Write-Error "The directory for -Backup does not exist: '$(Split-Path $Backup -Parent)'"
		exit 1
	}
}

Write-Host "`nChecking Windows Update policy values..." -ForegroundColor Cyan

# Look for the values that grey out the toggle, and note any other values in the same keys for context
$found = @()
$otherValues = @()
$ignoredProperties = @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')

try {
	foreach ($key in @($policyKey, $policyAuKey)) {
		if (-not (Test-Path -LiteralPath $key)) {
			continue
		}

		$properties = Get-ItemProperty -LiteralPath $key -ErrorAction Stop

		foreach ($property in $properties.PSObject.Properties) {
			if ($property.Name -in $ignoredProperties) {
				continue
			}

			$entry = [pscustomobject]@{ Key = $key; Name = $property.Name; Value = $property.Value }

			if ($targets | Where-Object { $_.Key -eq $key -and $_.Name -eq $property.Name }) {
				$found += $entry
			}
			else {
				$otherValues += $entry
			}
		}
	}
}
catch {
	Write-Host ""
	Write-Error "$ScriptName`: Failed to read the Windows Update policy keys: $($_.Exception.Message)"
	exit 1
}

foreach ($entry in $otherValues) {
	Write-Host "Other value (not removed): $($entry.Key)\$($entry.Name) = $($entry.Value)"
}

if ($found.Count -eq 0) {
	Write-Host "`n$ScriptName`: [$env:COMPUTERNAME] None of the values that grey out the toggle (NoAutoUpdate, AllowMUUpdateService) were found." -ForegroundColor Green
	Write-Host "`nIf the toggle is still greyed out, another policy (i.e. update server settings or device management) is probably controlling it."
	exit 0
}

foreach ($entry in $found) {
	Write-Host "Found: $($entry.Key)\$($entry.Name) = $($entry.Value)" -ForegroundColor Yellow
}

# Detect a domain-joined or MDM-enrolled PC, where policy may reapply the values
$managedReasons = @()
$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue

if ($computerSystem.PartOfDomain) {
	$managedReasons += 'domain-joined'
}

$enrollmentsKey = 'HKLM:\SOFTWARE\Microsoft\Enrollments'

if (Test-Path -LiteralPath $enrollmentsKey) {
	foreach ($enrollment in Get-ChildItem -LiteralPath $enrollmentsKey -ErrorAction SilentlyContinue) {
		if ((Get-ItemProperty -LiteralPath $enrollment.PSPath -Name 'ProviderID' -ErrorAction SilentlyContinue).ProviderID) {
			$managedReasons += 'MDM-enrolled'
			break
		}
	}
}

if ($managedReasons.Count -gt 0) {
	Write-Host ""
	Write-Warning "This PC appears to be $($managedReasons -join ' and '), so its administrator's policy may reapply these values, and removing them may go against their settings."

	if (-not $Force -and -not $Preview) {
		Write-Host ""
		Write-Error "$ScriptName`: Nothing was removed. Use -Force to continue anyway."
		exit 1
	}
}

# -Preview reports what would be removed and bypasses the prompt entirely
if ($Preview) {
	Write-Host "`n$ScriptName`: [$env:COMPUTERNAME] Preview complete. $($found.Count) value(s) would be removed. No changes were made." -ForegroundColor Green
	exit 0
}

if (-not $DeleteAll) {
	Write-Host ""
	$answer = Read-Host "Remove $($found.Count) value(s)? (Y/N)"

	if ($answer -notmatch '^[Yy]') {
		Write-Host "`n$ScriptName`: [$env:COMPUTERNAME] No changes were made."
		exit 0
	}
}

# Back up the policy keys first, and stop if the backup fails so nothing is removed without one
if ($Backup) {
	try {
		reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" $Backup /y 2>&1 | Out-Null

		if ($LASTEXITCODE -ne 0) {
			throw "reg export failed with exit code $LASTEXITCODE"
		}

		Write-Host "`nBackup saved to: $Backup" -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Error "$ScriptName`: Could not save the backup, so no values were removed: $($_.Exception.Message)"
		exit 1
	}
}

$removedCount = 0
$failedCount = 0

Write-Host ""

foreach ($entry in $found) {
	try {
		Remove-ItemProperty -LiteralPath $entry.Key -Name $entry.Name -ErrorAction Stop
		$removedCount++
		Write-Host "Removed: $($entry.Key)\$($entry.Name)"
	}
	catch {
		$failedCount++
		Write-Host ""
		Write-Warning "Could not remove $($entry.Key)\$($entry.Name): $($_.Exception.Message)"
	}
}

if ($failedCount -gt 0) {
	Write-Host "`n$ScriptName`: [$env:COMPUTERNAME] Removed $removedCount value(s), $failedCount could not be removed." -ForegroundColor Yellow
	exit 1
}

Write-Host "`n$ScriptName`: [$env:COMPUTERNAME] Removed $removedCount value(s). Close and reopen Settings > Windows Update > Advanced options to see the change." -ForegroundColor Green

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.