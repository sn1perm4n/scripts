# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes the contents of the following folders:
# C:\ProgramData\Samsung\Backup
# C:\ProgramData\Samsung\Samsung Magician\Site Link

#Requires -RunAsAdministrator

# Specify the directories to process
$directories = @(
	'C:\ProgramData\Samsung\Backup',
	'C:\ProgramData\Samsung\Samsung Magician\Site Link'
)

foreach ($dir in $directories) {
	Write-Host "`nChecking '$dir'..." -ForegroundColor Cyan

	if (Test-Path -Path $dir) {
		try {
			# Check if the directory has any items
			$items = Get-ChildItem -Path $dir -Force

			# Guard clause that activates and exits if the directory is empty
			if (-not $items) {
				Write-Warning "The directory '$dir' exists but is empty."
				continue
			}

			# Output what will be deleted
			Write-Host "`nDeleting the following items:" -ForegroundColor Cyan
			$items | ForEach-Object { Write-Host " - $($_.FullName)" }

			# Delete all files and folders within the directory
			$items | Remove-Item -Recurse -Force
			Write-Host "`nSuccessfully deleted the contents of '$dir'." -ForegroundColor Green
		}
		catch {
			Write-Error "An error occurred while trying to delete items in '$dir': $($_.Exception.Message)"
		}
	}
	else {
		Write-Warning "The directory '$dir' does not exist."
	}
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.