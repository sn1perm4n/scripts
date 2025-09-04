# This script deletes all .log files in a specific directory

# Specify the directory to process
$appdataLocalDiscordLogsFolder = "C:\Users\<PROFILE>\AppData\Local\Discord"

# Get all *.log files in the specified directory (and subfolders if -Recurse is added)
# -Filter "*.log" ensures only files with the .log extension are selected
# -File ensures only files are processed, not directories
$logFiles = Get-ChildItem -Path $appdataLocalDiscordLogsFolder -Filter *.log -File

# Delete each log file
foreach ($log in $logFiles) {
    try {
        Remove-Item -Path $log.FullName -Force
        Write-Host "Deleted: $($log.FullName)"
    } catch {
        Write-Host "Failed to delete: $($log.FullName) - $_"
    }
}

Write-Host "Successfully deleted all .log files from '$appdataLocalDiscordLogsFolder'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.