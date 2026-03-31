# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all *.log and *.txt files in a specific directory:
# C:\ProgramData\MSI\MSI Center

#Requires -RunAsAdministrator

# Specify the directory to process
$programdataMSIMSICenterFolder = 'C:\ProgramData\MSI\MSI Center'
$ScriptName = Split-Path $PSCommandPath -Leaf

Write-Host "`nChecking '$programdataMSIMSICenterFolder'..." -ForegroundColor Cyan

# Check if the directory exists
if (Test-Path -Path $programdataMSIMSICenterFolder) {
	# Get all *.log and *.txt files in the specified directory
	# -Include *.log, *.txt ensures only .log and .txt files are selected (\* must be included at the end of the variable name if -Include is used)
	# -File ensures only files are processed, not directories
	$files = Get-ChildItem -Path "$programdataMSIMSICenterFolder\*" -Include *.log, *.txt -File

	if (-not $files) {
		Write-Warning "No .log or .txt files found in '$programdataMSIMSICenterFolder'."
		exit 0
	}

	$totalBytesFreed = ($files | Measure-Object -Property Length -Sum).Sum
	if (-not $totalBytesFreed) { $totalBytesFreed = 0 }

	# Delete each .log and .txt file
	Write-Host "`nDeleting the following items:" -ForegroundColor Cyan
	foreach ($file in $files) {
		try {
			Write-Host " - $($file.FullName)"
			Remove-Item -Path $file.FullName -Force
		}
		catch {
			Write-Error "An error occurred while trying to delete '$($file.FullName)': $($_.Exception.Message)"
		}
	}

	# Summary
	$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
	$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
	$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" } else { "$totalFreedMB MB" }
	$fileWord = if ($files.Count -eq 1) { "file" } else { "files" }
	Write-Host "`n$ScriptName`: $($files.Count) $fileWord deleted, $freedDisplay freed." -ForegroundColor Green
}
else {
	Write-Warning "The directory '$programdataMSIMSICenterFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.