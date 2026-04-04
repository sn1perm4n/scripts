# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script checks a directory of scripts to determine which of them need to be run as administrator to function properly. It also shows which scripts already include an admin check, and also detects the presence of #Requires -RunAsAdministrator in those that require it.

# Specify the script directory to check
$ScriptPath = "\\Synology\Volume_1\Documents\Scripts\powershell_scripts"

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

Get-ChildItem $ScriptPath -Filter *.ps1 -Recurse | ForEach-Object {

	$content = Get-Content $_.FullName -Raw
	$flags = @()

	# Detect inline admin-rights check block
	$hasInlineAdminCheck =
		$content -match 'WindowsPrincipal' -and
		$content -match 'WindowsIdentity\]::GetCurrent' -and
		$content -match 'IsInRole' -and
		$content -match 'WindowsBuiltInRole\]::Administrator'

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

	# Output
	$Results += [PSCustomObject]@{
		Script = $_.Name
		NeedsAdmin = if ($needsAdmin) { 'Likely' } else { 'No' }
		AlreadyContainsAdminRights = if ($hasInlineAdminCheck) { 'Yes' } else { 'No' }
		Findings = if ($flags) { $flags -join '; ' } else { 'None detected' }
	}
}

# Display results
$Results | Sort-Object NeedsAdmin, Script |
	Format-Table Script, NeedsAdmin, AlreadyContainsAdminRights, Findings -Wrap

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.