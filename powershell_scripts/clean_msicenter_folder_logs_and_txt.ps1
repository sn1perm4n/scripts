# This script deletes all *.log and *.txt files in a specific directory

# Specify the directory to process
$programdataMSIMSICenterFolder = 'C:\ProgramData\MSI\MSI Center'

# Check if the directory exists
if (Test-Path -Path $programdataMSIMSICenterFolder) {
	# Get all *.log and *.txt files in the specified directory
	# -Include *.log, *.txt ensures only .log and .txt files are selected (\* must be included at the end of the variable name if -Include is used)
	# -File ensures only files are processed, not directories
	$files = Get-ChildItem -Path "$programdataMSIMSICenterFolder\*" -Include *.log, *.txt -File
	if (-not $files) {
		Write-Warning "No .log or .txt files found in '$programdataMSIMSICenterFolder'."
		return
	}
	# Delete each .log and .txt file
	foreach ($file in $files) {
		try {
			Write-Host "Deleting: $($file.FullName)"
			Remove-Item -Path $file.FullName -Force
		}
		catch {
			Write-Error "An error occurred while trying to delete items in '$programdataMSIMSICenterFolder': $($_.Exception.Message)."
		}
	}
	Write-Host "Successfully deleted all .log and .txt files in '$programdataMSIMSICenterFolder'."
}
else {
	Write-Warning "The directory '$programdataMSIMSICenterFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.