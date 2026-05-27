# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script checks a directory of PowerShell scripts to determine which ones likely require administrator rights, which already include an admin check, and which are missing #Requires -RunAsAdministrator

# Optional flags:
#     -Recurse: Include files in subdirectories
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Table: Display results as a formatted table instead of per-script output
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Table,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Recurse] [-SaveResults <PATH>] [-Table] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Recurse             Include files in subdirectories" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
	Write-Host "  -Table               Display results as a formatted table instead of per-script output" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
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

# Prompt user for folder path
$ScriptPath = Read-Host "`nEnter the full path to a .ps1 file or a folder containing scripts"

if (-not (Test-Path $ScriptPath -PathType Container)) {
	Write-Host ""
	Write-Error "The directory '$ScriptPath' does not exist."
	exit 1
}

# Command classifications
$ReadOps = 'Get-Content|Test-Path|Get-Item|Get-ChildItem|Select-String'
$WriteOps = 'New-Item|Set-Content|Add-Content|Out-File|Remove-Item|Copy-Item|Move-Item'
$AclOps = 'Set-Acl|Get-Acl|icacls'

$StrongAdminIndicators = @(
	'HKLM:',
	'HKCR:',
	'New-Service',
	'Set-Service',
	'Start-Service',
	'Stop-Service',
	'Register-ScheduledTask',
	'Enable-WindowsOptionalFeature',
	'dism(\.exe)?',
	'bcdedit',
	'netsh',
	'wevtutil',
	'pnputil',
	'Remove-AppxPackage'
)

$Results = @()
$FileOutputLines = @()

Get-ChildItem $ScriptPath -Filter *.ps1 -Recurse:$Recurse | ForEach-Object {

	$content = Get-Content $_.FullName -Raw
	$flags = @()

	# Detect #Requires -RunAsAdministrator or inline admin-rights check block
	$hasInlineAdminCheck =
		($content -match '(?im)^\s*#\s*Requires\s+-RunAsAdministrator\b') -or
		($content -match 'WindowsPrincipal' -and
		$content -match 'WindowsIdentity\]::GetCurrent' -and
		$content -match 'IsInRole' -and
		$content -match 'WindowsBuiltInRole\]::Administrator')

	# ProgramData analysis
	if ($content -match 'C:\\ProgramData') {

		if ($content -match $AclOps) {
			$flags += 'ProgramData ACL modification'
		}
		elseif ($content -match $WriteOps) {
			$flags += 'ProgramData write operation'
		}
		elseif ($content -match $ReadOps) {
			$flags += 'ProgramData read-only access'
		}
		else {
			$flags += 'ProgramData access (unclassified)'
		}
	}

	# Strong admin indicators
	foreach ($indicator in $StrongAdminIndicators) {
		if ($content -match $indicator) {
			$flags += "Admin indicator: $indicator"
		}
	}

	# Final verdict
	$needsAdmin =
		$flags -match 'ACL modification' -or
		$flags -match 'write operation' -or
		$flags -match 'Admin indicator'

	# Missing #Requires check
	if (
		$needsAdmin -and
		$content -notmatch '(?im)^\s*#\s*Requires\s+-RunAsAdministrator\b'
	) {
		$flags += 'Missing #Requires -RunAsAdministrator'
	}

	$Results += [PSCustomObject]@{
		Script = $_.Name
		NeedsAdmin = if ($needsAdmin) { 'Likely' } else { 'No' }
		AlreadyContainsAdminRights = if ($hasInlineAdminCheck) { 'Yes' } else { 'No' }
		Findings = if ($flags) { $flags -join '; ' } else { 'None detected' }
		FindingsArray = $flags
	}
}

# Summary counts
$totalScripts = $Results.Count
$likelyNeedsAdmin = ($Results | Where-Object { $_.NeedsAdmin -eq 'Likely' }).Count
$summaryLine = "$totalScripts script(s) checked, $likelyNeedsAdmin likely need(s) admin rights."

# Display results
Write-Host ""

if ($Table) {
	# Table output mode
	$Results | Sort-Object NeedsAdmin, Script |
		Format-Table Script, NeedsAdmin, AlreadyContainsAdminRights, Findings -Wrap

	if ($likelyNeedsAdmin -gt 0) {
		Write-Host $summaryLine -ForegroundColor Yellow
	}
	else {
		Write-Host $summaryLine -ForegroundColor Green
	}
}
else {
	# Per-script output mode
	$sorted = $Results | Sort-Object NeedsAdmin, Script
	foreach ($result in $sorted) {
		$color = if ($result.NeedsAdmin -eq 'Likely') { 'Yellow' } else { 'Green' }

		Write-Host $result.Script -ForegroundColor $color
		Write-Host "  Needs Admin:    $($result.NeedsAdmin)" -ForegroundColor $color
		Write-Host "  Admin Check:    $($result.AlreadyContainsAdminRights)" -ForegroundColor $color

		if ($result.FindingsArray.Count -gt 1) {
			Write-Host "  Findings:" -ForegroundColor $color
			foreach ($finding in $result.FindingsArray) {
				Write-Host "    - $finding" -ForegroundColor $color
			}
		}
		else {
			Write-Host "  Findings:       $($result.Findings)" -ForegroundColor $color
		}

		Write-Host ""
	}

	if ($likelyNeedsAdmin -gt 0) {
		Write-Host $summaryLine -ForegroundColor Yellow
	}
	else {
		Write-Host $summaryLine -ForegroundColor Green
	}
}

# Save results to text file if requested
if ($SaveResults) {
	foreach ($result in ($Results | Sort-Object NeedsAdmin, Script)) {
		$FileOutputLines += $result.Script
		$FileOutputLines += "  Needs Admin:    $($result.NeedsAdmin)"
		$FileOutputLines += "  Admin Check:    $($result.AlreadyContainsAdminRights)"

		if ($result.FindingsArray.Count -gt 1) {
			$FileOutputLines += "  Findings:"
			foreach ($finding in $result.FindingsArray) {
				$FileOutputLines += "    - $finding"
			}
		}
		else {
			$FileOutputLines += "  Findings:       $($result.Findings)"
		}

		$FileOutputLines += ""
	}

	while ($FileOutputLines[-1] -eq '') {
		$FileOutputLines = $FileOutputLines[0..($FileOutputLines.Count - 2)]
	}

	$FileOutputLines += ""
	$FileOutputLines += $summaryLine

	try {
		$outputString = ($FileOutputLines -join "`n")
		[System.IO.File]::WriteAllText($SaveResults, $outputString)
		Write-Host "`nResults saved to text file: $SaveResults" -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.