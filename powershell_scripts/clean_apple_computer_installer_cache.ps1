# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes the contents of a specific folder:
# C:\ProgramData\Apple Computer\Installer Cache

#Requires -RunAsAdministrator

# Specify the directory to process
$appleComputerInstallerCacheFolder = 'C:\ProgramData\Apple Computer\Installer Cache'

# Get the script name for summary output
$ScriptName = Split-Path $PSCommandPath -Leaf

Write-Host "`nChecking '$appleComputerInstallerCacheFolder'..." -ForegroundColor Cyan

# Check if the directory exists
if (Test-Path -Path $appleComputerInstallerCacheFolder) {
	try {
		# Check if the directory has any items
		$items = Get-ChildItem -Path $appleComputerInstallerCacheFolder -Force

		# Guard clause that activates and exits if the directory is empty
		if (-not $items) {
			Write-Warning "The directory '$appleComputerInstallerCacheFolder' exists but is empty."
			exit 0
		}

		# Calculate size before deletion
		$totalBytesFreed = (Get-ChildItem -Path $appleComputerInstallerCacheFolder -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
		if (-not $totalBytesFreed) { $totalBytesFreed = 0 }

		# Output what will be deleted
		Write-Host "`nDeleting the following items:" -ForegroundColor Cyan
		$items | ForEach-Object { Write-Host " - $($_.FullName)" }

		# Delete all files/folders within the directory
		Remove-Item -Path "$appleComputerInstallerCacheFolder\*" -Recurse -Force

		# Summary
		$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
		$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
		$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" } else { "$totalFreedMB MB" }
		Write-Host "`n$ScriptName`: Cleanup complete, $freedDisplay freed." -ForegroundColor Green
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$appleComputerInstallerCacheFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$appleComputerInstallerCacheFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.