# This script deletes the contents of a specific folder
#Requires -RunAsAdministrator

# Ensure script runs as Administrator
$principal = New-Object Security.Principal.WindowsPrincipal `
	([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $principal.IsInRole(
	[Security.Principal.WindowsBuiltInRole]::Administrator
)) {
	Write-Host "Please run this script as Administrator. Press any key to exit..." -ForegroundColor Red
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit 1
}

# Specify the directory to process
$programdataSamsungBackupFolder = 'C:\ProgramData\Samsung\Backup'

# Check if the directory exists
if (Test-Path -Path $programdataSamsungBackupFolder) {
	try {
		# Check if the directory has any items
		$items = Get-ChildItem -Path $programdataSamsungBackupFolder -Force
		# Guard clause that activates and exits if the directory is empty
		if (-not $items) {
			Write-Warning "The directory '$programdataSamsungBackupFolder' exists but is empty."
			return
		}
		# Output what will be deleted
		Write-Host "Deleting the following items:"
		$items | ForEach-Object { Write-Host " - $($_.FullName)" }
		# Delete all files and folders within the directory
		$items | Remove-Item -Recurse -Force
		Write-Host "Successfully deleted the contents of '$programdataSamsungBackupFolder'."
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$programdataSamsungBackupFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$programdataSamsungBackupFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.