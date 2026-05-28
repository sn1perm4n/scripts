# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes the contents of the following folders:
# C:\ProgramData\Samsung\Backup
# C:\ProgramData\Samsung\Samsung Magician\Site Link

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Specify the directories to process
$directories = @(
	'C:\ProgramData\Samsung\Backup',
	'C:\ProgramData\Samsung\Samsung Magician\Site Link'
)

$totalBytesFreed = 0
$directoriesProcessed = 0

foreach ($dir in $directories) {
	Write-Host "`nChecking '$dir'..." -ForegroundColor Cyan

	if (Test-Path -Path $dir) {
		try {
			# Check if the directory has any items
			$items = Get-ChildItem -Path $dir -Force

			# Guard clause that activates and exits if the directory is empty
			if (-not $items) {
				Write-Host ""
				Write-Warning "The directory '$dir' exists but is empty."
				continue
			}

			# Calculate size before deletion
			$dirSize = (Get-ChildItem -Path $dir -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
			if (-not $dirSize) { $dirSize = 0 }

			# Output what will be deleted
			Write-Host "`nDeleting the following items:" -ForegroundColor Cyan
			$items | ForEach-Object { Write-Host " - $($_.FullName)" }

			# Delete all files and folders within the directory
			$items | Remove-Item -Recurse -Force
			$totalBytesFreed += $dirSize
			$directoriesProcessed++
			Write-Host "`nSuccessfully deleted the contents of '$dir'." -ForegroundColor Green
		}
		catch {
			Write-Host ""
			Write-Error "An error occurred while trying to delete items in '$dir': $($_.Exception.Message)"
		}
	}
	else {
		Write-Host ""
		Write-Warning "The directory '$dir' does not exist."
	}
}

# Summary
if ($directoriesProcessed -gt 0) {
	$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
	$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
	$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" } else { "$totalFreedMB MB" }
	$dirWord = if ($directoriesProcessed -eq 1) { "directory" } else { "directories" }
	Write-Host "`n$ScriptName`: Cleanup complete. $freedDisplay freed across $directoriesProcessed $dirWord." -ForegroundColor Green
}
else {
	Write-Host "`n$ScriptName`: No cleanup was necessary." -ForegroundColor Yellow
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.