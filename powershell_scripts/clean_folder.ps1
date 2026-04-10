# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script is a parameterized utility that deletes the contents of a specified folder. It can be reused for any folder:
# Usage: .\clean_folder.ps1 -TargetFolder "C:\ProgramData\Apple Computer\Installer Cache"

# Required flag:
#     -TargetFolder <PATH>: Full path to the folder to clean
# Optional flags:
#     -Preview: Show what would be deleted without making any changes
#     -Recurse: Include files in subdirectories when listing and deleting
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[Parameter(Mandatory=$true)]
	[string]$TargetFolder,
	[switch]$Preview,
	[switch]$Recurse,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName -TargetFolder <PATH> [-Preview] [-Recurse] [-Help]" -ForegroundColor Cyan
	Write-Host "`nRequired:" -ForegroundColor Cyan
	Write-Host "  -TargetFolder <PATH>  Full path to the folder to clean" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Preview              Show what would be deleted without making any changes" -ForegroundColor Cyan
	Write-Host "  -Recurse              Include files in subdirectories when listing and deleting" -ForegroundColor Cyan
	Write-Host "  -Help                 Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

Write-Host "`nChecking '$TargetFolder'..." -ForegroundColor Cyan

if (-not (Test-Path -Path $TargetFolder)) {
	Write-Host ""
	Write-Warning "The directory '$TargetFolder' does not exist."
	exit 0
}

try {
	$items = Get-ChildItem -Path $TargetFolder -Force -Recurse:$Recurse

	if ($items.Count -eq 0) {
		Write-Host ""
		Write-Warning "The directory '$TargetFolder' exists but is empty."
		exit 0
	}

	# Calculate size before deletion
	$totalBytesFreed = (Get-ChildItem -Path $TargetFolder -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
	if (-not $totalBytesFreed) { $totalBytesFreed = 0 }

	Write-Host "`nThe following items will be deleted from '$TargetFolder':" -ForegroundColor Cyan
	$items | ForEach-Object { Write-Host " - $($_.FullName)" }

	if ($Preview) {
		$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
		$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
		$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" } else { "$totalFreedMB MB" }
		Write-Host "`n$ScriptName`: Preview complete. $freedDisplay would be freed." -ForegroundColor Cyan
		exit 0
	}

	# User confirmation
	$userInput = Read-Host "`nAre you sure you want to delete all contents? (Y/N)"
	if ($userInput -notmatch '^[Yy]$') {
		Write-Host "`nOperation cancelled by user." -ForegroundColor Yellow
		exit 0
	}

	# Delete all files and folders
	$items | Remove-Item -Recurse -Force

	# Summary
	$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
	$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
	$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" } else { "$totalFreedMB MB" }
	Write-Host "`n$ScriptName`: Cleanup complete, $freedDisplay freed." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Error "An error occurred while trying to delete items in '$TargetFolder': $($_.Exception.Message)"
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.