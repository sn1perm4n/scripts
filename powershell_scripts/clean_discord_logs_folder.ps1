# This script deletes all *.log files in a specific directory

# Specify the directory to process
$appdataLocalDiscordLogsFolder = 'C:\Users\<PROFILE>\AppData\Local\Discord'

# Check if the directory exists
if (Test-Path -Path $appdataLocalDiscordLogsFolder) {
	try {
		# Get all *.log files in the specified directory
		# -Filter "*.log" ensures only files with the .log extension are selected
		# -File ensures only files are processed, not directories
		$logFiles = Get-ChildItem -Path $appdataLocalDiscordLogsFolder -Filter *.log -File
		# Guard clause that activates and exits if no .log files are found
		if (-not $logFiles) {
			Write-Warning "No .log files exist in '$appdataLocalDiscordLogsFolder'."
			return
		}
		# Delete each log file
		foreach ($log in $logFiles) {
			Write-Host "Deleting the following item: $($log.FullName)"
			Remove-Item -Path $log.FullName -Force
		}
		Write-Host "Successfully deleted all .log files from '$appdataLocalDiscordLogsFolder'."
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$appdataLocalDiscordLogsFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$appdataLocalDiscordLogsFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.