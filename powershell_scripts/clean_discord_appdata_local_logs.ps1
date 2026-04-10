# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all *.log files in a specific directory:
# $env:LOCALAPPDATA\Discord (resolves to C:\Users\<username>\AppData\Local\Discord)

# Specify the directory to process
$appdataLocalDiscordLogsFolder = "$env:LOCALAPPDATA\Discord"

# Get the script name for summary output
$ScriptName = Split-Path $PSCommandPath -Leaf

Write-Host "`nChecking '$appdataLocalDiscordLogsFolder'..." -ForegroundColor Cyan

# Check if the directory exists
if (Test-Path -Path $appdataLocalDiscordLogsFolder) {
	try {
		# Get all *.log files in the specified directory
		$logFiles = Get-ChildItem -Path $appdataLocalDiscordLogsFolder -Filter *.log -File

		# Guard clause that activates and exits if no .log files are found
		if (-not $logFiles) {
			Write-Host ""
			Write-Warning "No .log files exist in '$appdataLocalDiscordLogsFolder'."
			exit 0
		}

		# Calculate size before deletion
		$totalBytesFreed = ($logFiles | Measure-Object -Property Length -Sum).Sum
		if (-not $totalBytesFreed) { $totalBytesFreed = 0 }

		# Delete each log file
		Write-Host "`nDeleting the following items:" -ForegroundColor Cyan
		foreach ($log in $logFiles) {
			Write-Host " - $($log.FullName)"
			Remove-Item -Path $log.FullName -Force
		}

		# Summary
		$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
		$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
		$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" } else { "$totalFreedMB MB" }
		$fileWord = if ($logFiles.Count -eq 1) { "file" } else { "files" }
		Write-Host "`n$ScriptName`: $($logFiles.Count) $fileWord deleted, $freedDisplay freed." -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Error "An error occurred while trying to delete items in '$appdataLocalDiscordLogsFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Host ""
	Write-Warning "The directory '$appdataLocalDiscordLogsFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.