# This script deletes all .log and .txt files in a specific directory

# Specify the directory to process
$programdataMSIMSICenterFolder = "C:\ProgramData\MSI\MSI Center"

# Get all *.log and *.txt files in the specified directory (and subfolders if -Recurse is added)
# -Filter "*.log" and "*.txt" ensures only files with the .log and .txt extensions are selected
# -File ensures only files are processed, not directories
$logFiles = Get-ChildItem -Path $programdataMSIMSICenterFolder -Filter *.log -File
$txtFiles = Get-ChildItem -Path $programdataMSIMSICenterFolder -Filter *.txt -File

# Delete each log file
foreach ($log in $logFiles) {
    try {
        Remove-Item -Path $log.FullName -Force
        Write-Host "Deleted: $($log.FullName)"
    } catch {
        Write-Host "Failed to delete: $($log.FullName) - $_"
    }
}

# Delete each txt file
foreach ($txt in $txtFiles) {
    try {
        Remove-Item -Path $txt.FullName -Force
        Write-Host "Deleted: $($txt.FullName)"
    } catch {
        Write-Host "Failed to delete: $($txt.FullName) - $_"
    }
}

Write-Host "All .log and .txt files successfully deleted from '$programdataMSIMSICenterFolder'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.