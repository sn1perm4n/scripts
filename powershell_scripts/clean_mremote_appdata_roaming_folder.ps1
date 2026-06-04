# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all *.backup files aside from the most recent one in a specific folder:
# $env:APPDATA\mRemoteNG (resolves to C:\Users\<username>\AppData\Roaming\mRemoteNG)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Specify the directory to process
$appdataRoamingMremoteng = "$env:APPDATA\mRemoteNG"

Write-Host "`nChecking '$appdataRoamingMremoteng'..." -ForegroundColor Cyan

# Check if the directory exists
if (Test-Path -Path $appdataRoamingMremoteng) {
	try {
		# Get all .backup files, sorted by LastWriteTime (newest first)
		$backupFiles = Get-ChildItem -Path $appdataRoamingMremoteng -Filter "*.backup" -File | Sort-Object LastWriteTime -Descending

		# Guard clause that activates and exits if 0 or 1 .backup file is found
		if ($backupFiles.Count -le 1) {
			Write-Host ""
			Write-Warning "Found $($backupFiles.Count) .backup file(s), nothing to delete."
			exit 0
		}

		# Keep the most recent .backup file
		$keepFile = $backupFiles[0]
		Write-Host "`nKeeping file: $($keepFile.FullName)" -ForegroundColor Green

		$totalBytesFreed = 0
		$deletedCount = 0

		# Delete the remaining .backup files
		foreach ($backupFile in $backupFiles | Select-Object -Skip 1) {
			$fileSize = $backupFile.Length
			Write-Host "Deleting: $($backupFile.FullName)" -ForegroundColor Yellow
			Remove-Item -Path $backupFile.FullName -Force
			$totalBytesFreed += $fileSize
			$deletedCount++
		}

		# Summary
		$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
		$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
		$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" }
else { "$totalFreedMB MB" }
		$fileWord = if ($deletedCount -eq 1) { "file" }
else { "files" }
		Write-Host "`n$ScriptName`: $deletedCount $fileWord deleted, $freedDisplay freed." -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Error "An error occurred while trying to delete items in '$appdataRoamingMremoteng': $($_.Exception.Message)"
		exit 1
	}
}
else {
	Write-Host ""
	Write-Warning "The directory '$appdataRoamingMremoteng' does not exist."
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.