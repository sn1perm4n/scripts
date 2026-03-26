# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all *.log files in a specific directory:
# $env:LOCALAPPDATA\Discord (resolves to C:\Users\<username>\AppData\Local\Discord)

# Specify the directory to process
$appdataLocalDiscordLogsFolder = '$env:LOCALAPPDATA\Discord'

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
			Write-Host "Deleting the following item: $($log.FullName)" -ForegroundColor Yellow
			Remove-Item -Path $log.FullName -Force
		}
		Write-Host "Successfully deleted all .log files from '$appdataLocalDiscordLogsFolder'." -ForegroundColor Green
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
