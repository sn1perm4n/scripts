# This script is a parameterized version that deletes the contents of a specified directory. It can be re-used for any directory by doing the following:
# Usage: .\clean_folder.ps1 -TargetFolder "C:\ProgramData\Apple Computer\Installer Cache"

param (
	[Parameter(Mandatory = $true)]
	[string]$TargetFolder
)

# Check if the directory exists
if (Test-Path -Path $TargetFolder) {
	try {
		# Check if the directory has any items
		$items = Get-ChildItem -Path $TargetFolder -Force

		# Guard clause that activates and exits if the directory is empty
		if (-not $items) {
			Write-Warning "The directory '$TargetFolder' exists but is empty."
			return
		}

		# Output what will be deleted
		Write-Host "Deleting the following items from '$TargetFolder':"
		$items | ForEach-Object { Write-Host " - $($_.FullName)" }

		# Delete all files and folders within the directory
		$items | Remove-Item -Recurse -Force

		Write-Host "Successfully deleted the contents of '$TargetFolder'."
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$TargetFolder': $($_.Exception.Message)."
	}
}
else {
	Write-Warning "The directory '$TargetFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.