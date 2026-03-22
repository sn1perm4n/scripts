# This script is a parameterized version that deletes the contents of a specified folder. It can be re-used for any folder by doing the following:
# Usage: .\clean_folder.ps1 -TargetFolder "C:\ProgramData\Apple Computer\Installer Cache"

#Requires -RunAsAdministrator

param (
	[Parameter(Mandatory = $true)]
	[string]$TargetFolder
)

if (-not (Test-Path -Path $TargetFolder)) {
	Write-Warning "The directory '$TargetFolder' does not exist."
	return
}

try {
	$items = Get-ChildItem -Path $TargetFolder -Force

	if ($items.Count -eq 0) {
		Write-Host "`nThe directory '$TargetFolder' exists but is empty." -ForegroundColor Yellow
		return
	}

	Write-Host "The following items will be deleted from '$TargetFolder':" -ForegroundColor Cyan
	$items | ForEach-Object { Write-Host " - $($_.FullName)" -ForegroundColor Cyan }

	# User confirmation (accepts y or Y)
	$userInput = Read-Host "Are you sure you want to delete all contents (Y/N)?"
	if ($userInput -notin @('y','Y')) {
		Write-Host "`nOperation cancelled by user." -ForegroundColor Yellow
		return
	}

	# Delete all files and folders
	$items | Remove-Item -Recurse -Force

	Write-Host "`nSuccessfully deleted the contents of '$TargetFolder'." -ForegroundColor Green
}
catch {
	Write-Error "An error occurred while trying to delete items in '$TargetFolder': $($_.Exception.Message)"
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.