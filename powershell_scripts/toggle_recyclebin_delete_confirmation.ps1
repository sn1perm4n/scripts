# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script enables or disables the Recycle Bin delete confirmation dialog in Windows 10 and 11

# Optional flags:
#     -Disable: Disable the delete confirmation dialog without prompting
#     -Enable:  Enable the delete confirmation dialog without prompting
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Disable,
	[switch]$Enable,
	[switch]$Help
)

$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Disable] [-Enable] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Disable  Disable the delete confirmation dialog without prompting" -ForegroundColor Cyan
	Write-Host "  -Enable   Enable the delete confirmation dialog without prompting" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

$regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'

if (-not $Enable -and -not $Disable) {
	Write-Host "`n1. Enable delete confirmation dialog"
	Write-Host "2. Disable delete confirmation dialog"
	Write-Host "`nPress 1 or 2 to continue..." -ForegroundColor Cyan
	while ($true) {
		$key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
		if ($key -eq '1' -or $key -eq '2') { break }
		Write-Host "`nInvalid input. Please press 1 or 2..." -ForegroundColor Yellow
	}
	$Enable = $key -eq '1'
	$Disable = $key -eq '2'
}

$enabling = $Enable -eq $true
$value = if ($enabling) { 1 } else { 0 }

Write-Host "`nChecking delete confirmation dialog status..." -ForegroundColor Cyan

try {
	if (-not (Test-Path $regPath)) {
		New-Item -Path $regPath -Force | Out-Null
	}

	$current = (Get-ItemProperty -Path $regPath -Name "ConfirmFileDelete" -ErrorAction SilentlyContinue).ConfirmFileDelete

	if ($enabling -and $current -eq 1) {
		Write-Host "`nDelete confirmation dialog is already enabled." -ForegroundColor Yellow
		exit 0
	}

	if (-not $enabling -and $current -eq 0) {
		Write-Host "`nDelete confirmation dialog is already disabled." -ForegroundColor Yellow
		exit 0
	}

	Set-ItemProperty -Path $regPath -Name "ConfirmFileDelete" -Type DWord -Value $value -Force -ErrorAction Stop

	if ($enabling) {
		Write-Host "`nDelete confirmation dialog successfully enabled." -ForegroundColor Green
	}
	else {
		Write-Host "`nDelete confirmation dialog successfully disabled." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	if ($enabling) {
		Write-Error "Failed to enable delete confirmation dialog: $($_.Exception.Message)"
	}
	else {
		Write-Error "Failed to disable delete confirmation dialog: $($_.Exception.Message)"
	}
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.