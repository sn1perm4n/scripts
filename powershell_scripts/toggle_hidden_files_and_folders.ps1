# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script shows or hides hidden files and folders by making Registry changes and refreshing File Explorer to make the changes active

# Optional flags:
#     -Hide:      Hide hidden files and folders without prompting
#     -Preview:   Report current visibility status without changing anything
#     -Show:      Show hidden files and folders without prompting
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Hide,
	[switch]$Preview,
	[switch]$Show,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Hide] [-Preview] [-Show] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Hide     Hide hidden files and folders without prompting" -ForegroundColor Cyan
	Write-Host "  -Preview  Report current visibility status without changing anything" -ForegroundColor Cyan
	Write-Host "  -Show     Show hidden files and folders without prompting" -ForegroundColor Cyan
	Write-Host "  -Help     Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

$registryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

# -Hide and -Show are mutually exclusive
if ($Hide -and $Show) {
	Write-Host ""
	Write-Error "-Hide and -Show are mutually exclusive."
	exit 1
}

# -Preview reports current status and bypasses the interactive menu entirely
if ($Preview) {
	try {
		$props = Get-ItemProperty -Path $registryPath -ErrorAction Stop
		$hidden = $props.Hidden
		$showSuperHidden = $props.ShowSuperHidden

		if ($hidden -eq 1 -and $showSuperHidden -eq 1) {
			Write-Host "Hidden files and folders are currently VISIBLE."
		}
		elseif ($hidden -eq 0 -and $showSuperHidden -eq 0) {
			Write-Host "Hidden files and folders are currently HIDDEN."
		}
		else {
			Write-Host "Hidden files and folders are in a mixed state: Hidden=$hidden, ShowSuperHidden=$showSuperHidden."
		}
	}
	catch {
		Write-Host ""
		Write-Error "$ScriptName`: Failed to check hidden files and folders visibility status: $($_.Exception.Message)"
		exit 1
	}

	exit 0
}

# If neither flag is passed, fall through to interactive menu
if (-not $Show -and -not $Hide) {
	Write-Host "`n1. Show hidden files and folders"
	Write-Host "2. Hide hidden files and folders"
	Write-Host "`nPress 1 or 2 to continue..." -ForegroundColor Cyan

	while ($true) {
		$key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
		if ($key -eq '1' -or $key -eq '2') { break }
		Write-Host ""
		Write-Warning "Invalid input. Please press 1 or 2..."
	}

	$Show = $key -eq '1'
	$Hide = $key -eq '2'
}

$showing = $Show -eq $true

Write-Host "`nChecking hidden files and folders visibility status..." -ForegroundColor Cyan

try {
	$props = Get-ItemProperty -Path $registryPath -ErrorAction Stop
	$hidden = $props.Hidden
	$showSuperHidden = $props.ShowSuperHidden

	if ($showing) {
		if ($hidden -eq 1 -and $showSuperHidden -eq 1) {
			Write-Host ""
			Write-Warning "Hidden files and folders are already visible."
			exit 0
		}
		Set-ItemProperty -Path $registryPath -Name Hidden -Type DWord -Value 1 -Force -ErrorAction Stop
		Set-ItemProperty -Path $registryPath -Name ShowSuperHidden -Type DWord -Value 1 -Force -ErrorAction Stop
		# Refresh File Explorer to apply changes immediately
		$shell = New-Object -ComObject Shell.Application
		$shell.Windows() | ForEach-Object { $_.Refresh() }
		Write-Host "`n$ScriptName`: Hidden files and folders made visible successfully." -ForegroundColor Green
	}
	else {
		if ($hidden -eq 0 -and $showSuperHidden -eq 0) {
			Write-Host ""
			Write-Warning "Hidden files and folders are already hidden."
			exit 0
		}
		Set-ItemProperty -Path $registryPath -Name Hidden -Type DWord -Value 0 -Force -ErrorAction Stop
		Set-ItemProperty -Path $registryPath -Name ShowSuperHidden -Type DWord -Value 0 -Force -ErrorAction Stop
		# Refresh File Explorer to apply changes immediately
		$shell = New-Object -ComObject Shell.Application
		$shell.Windows() | ForEach-Object { $_.Refresh() }
		Write-Host "`n$ScriptName`: Hidden files and folders hidden successfully." -ForegroundColor Green
	}
}
catch {
	Write-Host ""
	if ($showing) {
		Write-Error "$ScriptName`: Failed to show hidden files and folders: $($_.Exception.Message)"
	}
	else {
		Write-Error "$ScriptName`: Failed to hide hidden files and folders: $($_.Exception.Message)"
	}
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.