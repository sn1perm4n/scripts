# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes the contents of a specific folder:
# C:\ProgramData\NVIDIA Corporation\Downloader

#Requires -RunAsAdministrator

# Get the script name for summary output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Specify the directory to process
$programdataNvidiacorporationDownloader = 'C:\ProgramData\NVIDIA Corporation\Downloader'

Write-Host "`nChecking '$programdataNvidiacorporationDownloader'..." -ForegroundColor Cyan

# Check if the directory exists
if (Test-Path -Path $programdataNvidiacorporationDownloader) {
	try {
		# Check if the directory has any items
		$items = Get-ChildItem -Path $programdataNvidiacorporationDownloader -Force

		# Guard clause that activates and exits if the directory is empty
		if (-not $items) {
			Write-Host ""
			Write-Warning "The directory '$programdataNvidiacorporationDownloader' exists but is empty."
			exit 0
		}

		# Calculate size before deletion
		$totalBytesFreed = (Get-ChildItem -Path $programdataNvidiacorporationDownloader -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
		if (-not $totalBytesFreed) { $totalBytesFreed = 0 }

		# Output what will be deleted
		Write-Host "`nDeleting the following items:" -ForegroundColor Cyan
		$items | ForEach-Object { Write-Host " - $($_.FullName)" }

		# Delete all files and folders within the directory
		$items | Remove-Item -Recurse -Force

		# Summary
		$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
		$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
		$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" } else { "$totalFreedMB MB" }
		Write-Host "`n$ScriptName`: Cleanup complete, $freedDisplay freed." -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Error "An error occurred while trying to delete items in '$programdataNvidiacorporationDownloader': $($_.Exception.Message)"
		exit 1
	}
}
else {
	Write-Host ""
	Write-Warning "The directory '$programdataNvidiacorporationDownloader' does not exist."
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.